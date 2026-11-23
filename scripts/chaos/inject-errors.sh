#!/usr/bin/env bash
# Sets the app's injected failure rate. 0.2 = 20% of requests return HTTP 500.
# Watch the "orders-api · SLOs" dashboard: burn rate climbs within minutes,
# and the fast-burn page alert fires once the 5m and 1h windows both exceed 14.4x.
set -euo pipefail
tenant="${1:?usage: $0 <tenant> <failure_rate 0..1> [latency_ms]}"
rate="${2:?failure rate required}"
latency="${3:-0}"

key=$(kubectl -n "$tenant" get secret orders-api-secrets -o jsonpath='{.data.API_KEY}' | base64 -d)

# Chaos state lives in each pod's memory, so set it on every replica directly
# (a Service port-forward would only ever reach one pod).
for pod in $(kubectl -n "$tenant" get pods -l app=orders-api -o name); do
  kubectl -n "$tenant" port-forward "$pod" 18001:8000 >/dev/null 2>&1 &
  ppf=$!
  sleep 1
  curl -fsS -X PUT localhost:18001/admin/chaos \
    -H "X-API-Key: ${key}" -H 'Content-Type: application/json' \
    -d "{\"failure_rate\": ${rate}, \"latency_ms\": ${latency}}" && echo "  <- ${pod}"
  kill $ppf 2>/dev/null || true
  wait $ppf 2>/dev/null || true
done
