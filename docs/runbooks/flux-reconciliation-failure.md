# Runbook: Flux Kustomization or HelmRelease not ready

```bash
flux get all -A --status-selector ready=false
flux logs --level=error --since=30m
kubectl -n <ns> describe kustomization <name>
kubectl -n <ns> describe helmrelease <name>
```

| Message | Cause | Fix |
|---|---|---|
| `dependency 'x' is not ready` | an upstream layer failed | fix the upstream one first |
| `kustomize build failed` | YAML or path error | `kustomize build <path>` locally; `make validate` |
| `forbidden: User "system:serviceaccount:team-a:flux-reconciler"` | tenant manifest needs a permission it shouldn't have, or a new CRD isn't in `tenant-deployer-crds` | decide if it's allowed; if yes, add it in `tenants/` |
| `no matches for kind` | CRD not installed yet | check infra-controllers is Ready |
| HelmRelease `install retries exhausted` | bad values or chart | `helm -n <ns> history <release>`, fix values, then `flux suspend` / `flux resume` to reset |
| `health check failed` with `wait: true` | pods not Ready | debug the workload, not Flux |

Then: `flux reconcile kustomization <name> -n <ns> --with-source`
