import os

os.environ["WARMUP_SECONDS"] = "0"
os.environ["API_KEY"] = "test-key"

from fastapi.testclient import TestClient  # noqa: E402

from app import main  # noqa: E402

main.API_KEY = "test-key"


def client():
    return TestClient(main.app)


def test_liveness_and_readiness():
    with client() as c:
        assert c.get("/healthz").status_code == 200
        assert c.get("/readyz").json() == {"status": "ready"}


def test_create_and_get_order():
    with client() as c:
        r = c.post("/orders", json={"item": "coffee", "quantity": 2})
        assert r.status_code == 201
        oid = r.json()["id"]
        assert c.get(f"/orders/{oid}").json()["item"] == "coffee"
        assert c.get("/orders/does-not-exist").status_code == 404


def test_validation_rejects_bad_input():
    with client() as c:
        assert c.post("/orders", json={"item": "", "quantity": 0}).status_code == 422


def test_metrics_use_route_template_not_raw_path():
    with client() as c:
        c.get("/orders/abc-123")
        body = c.get("/metrics").text
        assert 'route="/orders/{order_id}"' in body
        assert "abc-123" not in body


def test_chaos_requires_api_key():
    with client() as c:
        assert c.put("/admin/chaos", json={"failure_rate": 1}).status_code == 401


def test_chaos_injects_failures_and_heals():
    with client() as c:
        h = {"X-API-Key": "test-key"}
        assert c.put("/admin/chaos", json={"failure_rate": 1.0}, headers=h).status_code == 200
        assert c.get("/orders").status_code == 500
        # Health endpoints are never affected by chaos, so probes stay honest.
        assert c.get("/healthz").status_code == 200
        c.put("/admin/chaos", json={"failure_rate": 0}, headers=h)
        assert c.get("/orders").status_code == 200
