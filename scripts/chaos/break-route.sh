#!/usr/bin/env bash
# Simulates a bad manual change: points the HTTPRoute at a port the Service
# doesn't have. What to observe:
#   1. curl through the Gateway returns 500/503
#   2. kubectl describe httproute shows ResolvedRefs=False with a reason
#   3. within the Flux interval (5m, or `flux reconcile ks orders-api -n <tenant>`)
#      Flux detects drift and puts Git's version back. Git wins.
set -euo pipefail
tenant="${1:?usage: $0 <tenant>}"
kubectl -n "$tenant" patch httproute orders-api --type=json \
  -p='[{"op":"replace","path":"/spec/rules/0/backendRefs/0/port","value":8080}]'
echo "Route broken. Inspect it:"
echo "  kubectl -n ${tenant} get httproute orders-api -o jsonpath='{.status.parents[0].conditions}' | jq"
echo "Heal it the GitOps way:"
echo "  flux reconcile kustomization orders-api -n ${tenant} --with-source"
