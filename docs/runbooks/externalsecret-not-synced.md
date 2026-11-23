# Runbook: ExternalSecretNotSynced

**Meaning:** an ExternalSecret has failed to sync from Vault for 10 minutes.
The existing Kubernetes Secret keeps working, but new pods fail if it was never
created, and rotations don't arrive.

```bash
kubectl -n <ns> describe externalsecret <name>   # Events show the Vault error
kubectl -n <ns> describe secretstore vault        # Ready condition
kubectl -n external-secrets logs deploy/external-secrets --since=15m | grep <ns>
```

| Error | Likely cause | Fix |
|---|---|---|
| `permission denied` / 403 | policy doesn't cover the path, or wrong role | check `vault policy read <tenant>` and the SecretStore role |
| `invalid role name` | role missing (Vault dev mode restarted) | `make vault-setup` |
| `secret not found` / 404 | key or property name wrong | `vault kv get tenants/<tenant>/<key>` |
| `connection refused` / timeout | Vault down or blocked by NetworkPolicy | `kubectl -n vault get pods`; check egress from external-secrets ns |

Force a retry after fixing: `kubectl -n <ns> annotate externalsecret <name> force-sync=$(date +%s) --overwrite`
