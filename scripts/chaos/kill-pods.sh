#!/usr/bin/env bash
# Deletes a random orders-api pod every 20s for 2 minutes while you run `make load`.
# Hypothesis: with 2+ replicas, maxUnavailable=0, a PDB and readiness gating,
# users see no 5xx and the availability SLO does not move.
set -euo pipefail
tenant="${1:?usage: $0 <tenant>}"
end=$((SECONDS + 120))
while [ $SECONDS -lt $end ]; do
  pod=$(kubectl -n "$tenant" get pods -l app=orders-api -o name | shuf -n1)
  echo "$(date +%T) deleting ${pod}"
  kubectl -n "$tenant" delete "$pod" --wait=false
  sleep 20
done
kubectl -n "$tenant" get pods -l app=orders-api
