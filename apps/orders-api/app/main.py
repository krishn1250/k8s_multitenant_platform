"""orders-api: a deliberately small service used to exercise the platform.

It exposes RED metrics (rate, errors, duration) for the SLOs, has separate
liveness and readiness endpoints, shuts down gracefully, and has a protected
fault-injection endpoint so error-budget burn can be demonstrated on demand.
"""

from __future__ import annotations

import asyncio
import os
import random
import signal
import time
import uuid
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import Depends, FastAPI, Header, HTTPException, Request, Response
from fastapi.responses import JSONResponse
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, generate_latest
from pydantic import BaseModel, Field

SERVICE = "orders-api"
VERSION = os.getenv("APP_VERSION", "dev")
TENANT = os.getenv("TENANT", "local")
API_KEY = os.getenv("API_KEY", "")  # delivered from Vault via External Secrets

REQUESTS = Counter(
    "http_requests_total",
    "HTTP requests by route template and status code.",
    ["method", "route", "status"],
)
LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency by route template.",
    ["method", "route"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.2, 0.3, 0.5, 1.0, 2.5, 5.0),
)
INFLIGHT = Gauge("http_requests_in_flight", "Requests currently being served.")
CHAOS_FAILURE_RATE = Gauge("chaos_failure_rate", "Configured injected failure rate (0-1).")
CHAOS_LATENCY = Gauge("chaos_latency_seconds", "Configured injected latency.")
BUILD_INFO = Gauge("app_build_info", "Build metadata.", ["version", "tenant"])
BUILD_INFO.labels(VERSION, TENANT).set(1)


class ChaosConfig(BaseModel):
    failure_rate: float = Field(0.0, ge=0.0, le=1.0)
    latency_ms: int = Field(0, ge=0, le=10_000)


class OrderIn(BaseModel):
    item: str = Field(..., min_length=1, max_length=100)
    quantity: int = Field(..., ge=1, le=1000)


class Order(OrderIn):
    id: str
    status: str = "created"
    created_at: float


class State:
    def __init__(self) -> None:
        self.ready = False
        self.shutting_down = False
        self.chaos = ChaosConfig()
        self.orders: dict[str, Order] = {}


state = State()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Simulate warm-up (cache load, connection pools). Readiness stays false
    # until this finishes, which is why the startup probe exists.
    await asyncio.sleep(float(os.getenv("WARMUP_SECONDS", "2")))
    state.ready = True

    # On SIGTERM: fail readiness first so endpoints stop routing to us, keep
    # serving in-flight requests, then let uvicorn exit. Pairs with preStop.
    loop = asyncio.get_running_loop()
    original = signal.getsignal(signal.SIGTERM)

    def _on_sigterm(signum, frame):
        state.ready = False
        state.shutting_down = True
        if callable(original):
            loop.call_later(float(os.getenv("DRAIN_SECONDS", "5")), original, signum, frame)

    signal.signal(signal.SIGTERM, _on_sigterm)
    yield
    state.ready = False


app = FastAPI(title=SERVICE, version=VERSION, lifespan=lifespan)

UNMETERED = {"/metrics", "/healthz", "/readyz"}


@app.middleware("http")
async def metrics_and_chaos(request: Request, call_next):
    path = request.url.path
    if path in UNMETERED:
        return await call_next(request)

    INFLIGHT.inc()
    start = time.perf_counter()
    status = 500
    try:
        chaos = state.chaos
        if chaos.latency_ms and not path.startswith("/admin"):
            await asyncio.sleep(chaos.latency_ms / 1000)
        if chaos.failure_rate and not path.startswith("/admin") and random.random() < chaos.failure_rate:
            response: Response = JSONResponse({"error": "injected failure"}, status_code=500)
        else:
            response = await call_next(request)
        status = response.status_code
        return response
    finally:
        # Use the route template (/orders/{order_id}), never the raw path,
        # so metric cardinality stays bounded.
        route = getattr(request.scope.get("route"), "path", "unmatched")
        REQUESTS.labels(request.method, route, str(status)).inc()
        LATENCY.labels(request.method, route).observe(time.perf_counter() - start)
        INFLIGHT.dec()


def require_api_key(x_api_key: Optional[str] = Header(default=None)) -> None:
    if not API_KEY:
        raise HTTPException(503, "admin API disabled: API_KEY not configured")
    if x_api_key != API_KEY:
        raise HTTPException(401, "invalid api key")


@app.get("/healthz")
async def healthz():
    """Liveness: the process is alive and the event loop responds. No dependencies."""
    return {"status": "ok"}


@app.get("/readyz")
async def readyz():
    """Readiness: safe to receive traffic (warmed up, not draining)."""
    if not state.ready:
        return JSONResponse({"status": "not ready", "draining": state.shutting_down}, status_code=503)
    return {"status": "ready"}


@app.get("/metrics")
async def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/")
async def root():
    return {"service": SERVICE, "version": VERSION, "tenant": TENANT}


@app.post("/orders", status_code=201, response_model=Order)
async def create_order(body: OrderIn):
    order = Order(id=str(uuid.uuid4()), created_at=time.time(), **body.model_dump())
    state.orders[order.id] = order
    return order


@app.get("/orders", response_model=list[Order])
async def list_orders(limit: int = 50):
    limit = max(1, min(limit, 200))
    return list(state.orders.values())[-limit:]


@app.get("/orders/{order_id}", response_model=Order)
async def get_order(order_id: str):
    order = state.orders.get(order_id)
    if not order:
        raise HTTPException(404, "order not found")
    return order


@app.get("/admin/chaos", dependencies=[Depends(require_api_key)])
async def get_chaos():
    return state.chaos


@app.put("/admin/chaos", dependencies=[Depends(require_api_key)])
async def set_chaos(cfg: ChaosConfig):
    state.chaos = cfg
    CHAOS_FAILURE_RATE.set(cfg.failure_rate)
    CHAOS_LATENCY.set(cfg.latency_ms / 1000)
    return cfg
