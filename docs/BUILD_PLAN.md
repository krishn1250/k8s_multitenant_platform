# Build plan

Build this in stages, one stage per day or two, committing as you go. Don't
copy everything in at once: getting each layer green before adding the next is
how you'll learn what each piece does, and the commit history will show it.

| Stage | Add | Done when | Commit message idea |
|---|---|---|---|
| 1 | `terraform/` | `kubectl get nodes` shows 3 nodes | `feat(infra): kind cluster with terraform` |
| 2 | Flux bootstrap, `clusters/dev/flux-system` | `flux check` passes | `feat(gitops): bootstrap flux` |
| 3 | `apps/orders-api/app` + Dockerfile + tests | `pytest` green, `docker run` works | `feat(app): orders-api with RED metrics` |
| 4 | `infrastructure/controllers` (Envoy Gateway only) + `configs/gateway.yaml` | Gateway `Programmed=True` | `feat(gateway): envoy gateway + shared gateway` |
| 5 | `tenants/` (without SecretStore) + app manifests (without ExternalSecret) | `curl -H 'Host: team-a.orders.local'` works | `feat(tenancy): namespaces, rbac, netpol, quotas` |
| 6 | Vault + ESO + SecretStore + ExternalSecret + `vault-setup.sh` | `kubectl get externalsecret -A` all `SecretSynced` | `feat(secrets): vault + external secrets per tenant` |
| 7 | kube-prometheus-stack + ServiceMonitor | target `UP` in Prometheus | `feat(observability): prometheus + grafana` |
| 8 | Sloth + `slo/` + dashboard | SLO dashboard shows data | `feat(slo): availability and latency slos` |
| 9 | CI workflow + image automation | push to main → new image in dev | `ci: validate, test, build; flux image automation` |
| 10 | Chaos experiments + postmortems | at least 3 written up | `docs: chaos experiments and postmortems` |

Things will break at each stage (chart values, CRD ordering, NetworkPolicy
blocking something you forgot). That's the point. Keep notes; the best ones
become postmortems and interview stories.
