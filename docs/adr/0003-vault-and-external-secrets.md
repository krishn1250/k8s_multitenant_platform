# ADR 0003: Vault + External Secrets Operator, dev mode locally

**Status:** accepted

## Context
Apps need secrets without secrets ever being committed to Git, and tenants must
not be able to read each other's secrets.

## Decision
- Secrets live in Vault kv-v2 under `tenants/<tenant>/...`.
- External Secrets Operator syncs them into ordinary Kubernetes Secrets, so
  apps only read env vars or files and don't depend on Vault.
- Each tenant namespace has its own `SecretStore` that logs in with Vault's
  Kubernetes auth method using the tenant's `vault-reader` service account.
  The Vault role is bound to that SA *and* namespace, and its policy only
  allows that tenant's path.

## Why not
- **Sealed Secrets / SOPS:** encrypted secrets in Git work, but rotation and
  audit are weaker and there is no central place to revoke access.
- **Vault Agent sidecar:** couples every pod to Vault and adds a container per pod.
- **One ClusterSecretStore:** simpler, but any namespace could request any path.

## Consequences
- Locally Vault runs in dev mode: in-memory, root token `root`. Data is lost on
  restart (`make vault-setup` restores it). Production would use HA Raft
  storage, auto-unseal (Azure Key Vault / AWS KMS) and no root token in use.
- `refreshInterval: 1m` means a rotated secret reaches the Kubernetes Secret
  within a minute; the app still needs a restart or reload to pick it up.
