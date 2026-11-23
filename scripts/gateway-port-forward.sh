#!/usr/bin/env bash
# Envoy Gateway creates a Service for each Gateway. Find ours and forward it.
set -euo pipefail
svc=$(kubectl -n envoy-gateway-system get svc \
  -l gateway.envoyproxy.io/owning-gateway-name=shared,gateway.envoyproxy.io/owning-gateway-namespace=infra-gateway \
  -o jsonpath='{.items[0].metadata.name}')
echo "Gateway service: $svc -> http://localhost:8080"
echo "Try: curl -H 'Host: team-a.orders.local' localhost:8080/"
kubectl -n envoy-gateway-system port-forward "svc/${svc}" 8080:80
