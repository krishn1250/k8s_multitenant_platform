# Runbook: OrdersApiHighErrorBudgetBurn / OrdersApiHighLatencyBudgetBurn

**Meaning:** the tenant's orders-api is consuming its error budget faster than
the SLO allows. `severity=page` means fast burn (act now); `ticket` means slow
burn (fix this week).

## 1. Scope it (2 min)
- Grafana → *orders-api · SLOs* → pick the tenant from the `tenant` label.
- One tenant or both? Both points at the platform (Gateway, nodes, DNS); one
  points at that tenant's app or config.
- Errors or latency? Which route? (`sum by (route, status) (rate(http_requests_total{namespace="team-a"}[5m]))`)

## 2. Did something change?
```bash
flux get kustomizations -n team-a
kubectl -n team-a rollout history deploy/orders-api
git log --oneline -10 -- apps/orders-api tenants/team-a
```
A deploy in the last hour is the first suspect. **Roll back first, debug after:**
revert the commit and `flux reconcile ks orders-api -n team-a --with-source`.

## 3. Is the app healthy?
```bash
kubectl -n team-a get pods -l app=orders-api -o wide
kubectl -n team-a describe pod <pod>     # restarts, OOMKilled, probe failures
kubectl -n team-a logs deploy/orders-api --since=15m
kubectl -n team-a top pods
```

## 4. Is traffic reaching it correctly?
```bash
kubectl -n team-a get httproute orders-api -o jsonpath='{.status.parents[0].conditions}' | jq
kubectl -n team-a get endpointslices -l kubernetes.io/service-name=orders-api
```
`ResolvedRefs=False` → broken backend ref. No ready endpoints → readiness failing.

## 5. Lab-only cause
Fault injection may be on: `kubectl -n team-a port-forward deploy/orders-api 18001:8000` then
`curl -H "X-API-Key: ..." localhost:18001/admin/chaos`. Turn it off with `make chaos-heal`.

## After
If budget dropped below 50%, follow the error budget policy in ADR 0004 and
write a postmortem.
