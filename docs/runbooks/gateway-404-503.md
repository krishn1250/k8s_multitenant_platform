# Runbook: 404 / 503 through the Gateway

- **404 from Envoy:** no HTTPRoute matched. Check the Host header matches
  `<tenant>.orders.local`, and that the route is attached:
  `kubectl -n <tenant> get httproute orders-api -o yaml` → `status.parents[].conditions`
  `Accepted=False, reason=NotAllowedByListeners` means the namespace lacks
  `platform.io/tenant=true`.
- **500/503 from Envoy:** route matched but no healthy backend.
  `ResolvedRefs=False` → wrong Service name/port in `backendRefs`.
  Endpoints empty → pods not Ready (check readiness probe).
  Endpoints present but still 503 → NetworkPolicy blocking
  `envoy-gateway-system` → app on 8000.
- Envoy's own view: `kubectl -n envoy-gateway-system logs deploy/<envoy-deploy> -c envoy`
