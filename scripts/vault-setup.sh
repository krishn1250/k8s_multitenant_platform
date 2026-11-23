#!/usr/bin/env bash
# Configures the dev Vault for per-tenant isolation:
#   - kv-v2 engine mounted at tenants/
#   - Kubernetes auth so pods can log in with their service account token
#   - one policy + role per tenant, scoped to tenants/data/<tenant>/*
#   - a random API_KEY per tenant
# Safe to re-run.
set -euo pipefail

TENANTS=(team-a team-b)
vault() { kubectl -n vault exec -i vault-0 -- env VAULT_TOKEN=root VAULT_ADDR=http://127.0.0.1:8200 vault "$@"; }

echo "==> waiting for vault-0"
kubectl -n vault wait --for=condition=Ready pod/vault-0 --timeout=180s

vault secrets list | grep -q '^tenants/' || vault secrets enable -path=tenants kv-v2
vault auth list | grep -q '^kubernetes/' || vault auth enable kubernetes

# Vault runs in-cluster, so it can use its own service account to validate tokens.
vault write auth/kubernetes/config kubernetes_host="https://kubernetes.default.svc:443"

for t in "${TENANTS[@]}"; do
  echo "==> tenant ${t}"
  printf 'path "tenants/data/%s/*" {\n  capabilities = ["read"]\n}\npath "tenants/metadata/%s/*" {\n  capabilities = ["read", "list"]\n}\n' "$t" "$t" \
    | vault policy write "$t" -

  vault write "auth/kubernetes/role/${t}" \
    bound_service_account_names=vault-reader \
    bound_service_account_namespaces="$t" \
    policies="$t" \
    ttl=1h

  if ! vault kv get "tenants/${t}/orders-api" >/dev/null 2>&1; then
    vault kv put "tenants/${t}/orders-api" API_KEY="$(openssl rand -hex 16)" >/dev/null
    echo "    seeded tenants/${t}/orders-api"
  fi
done

echo "==> forcing ExternalSecrets to sync now"
for t in "${TENANTS[@]}"; do
  kubectl -n "$t" annotate externalsecret orders-api force-sync="$(date +%s)" --overwrite 2>/dev/null || true
done
echo "done. Check: kubectl get externalsecret -A"
