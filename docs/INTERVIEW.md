# Interview guide for this project

## 60-second pitch
"I built a small multi-tenant platform on Kubernetes that mirrors what I run
at work. Two teams share one cluster; each is isolated with its own namespace,
RBAC, default-deny network policies, quotas and Vault policy. Everything is
deployed by Flux from Git, and tenant apps are applied by Flux impersonating
the tenant's own service account, so a tenant can't deploy outside its
namespace. I added the part I didn't have at work: SLOs. Each service has an
availability and a latency SLO, Sloth generates multi-window burn-rate alerts,
and I ran chaos experiments (error injection, pod kills, manual drift, Vault
outage) and wrote postmortems for each."

## Questions you should be ready for

**Why liveness and readiness are separate?**
Liveness answers "is the process stuck, should kubelet restart it?" Readiness
answers "should this pod get traffic right now?" If liveness checked the
database, a DB outage would restart every pod at once and make recovery
slower. Here readiness fails during warm-up and during drain on SIGTERM;
liveness only checks the event loop.

**Walk me through a request from curl to pod.**
Host header `team-a.orders.local` → port-forward to Envoy Service → Envoy
matches the listener `*.orders.local` and the HTTPRoute from team-a (allowed
because the namespace has `platform.io/tenant=true`) → backendRef Service
`orders-api:80` → EndpointSlice of ready pods → NetworkPolicy
`allow-from-gateway` permits envoy-gateway-system → pod port 8000.

**How does a secret get into the pod?**
Vault kv-v2 `tenants/team-a/orders-api` → ESO reads it via the team-a
SecretStore, which logs in to Vault with the `vault-reader` SA token using
Kubernetes auth → Vault checks the role (SA name + namespace) → policy allows
only `tenants/data/team-a/*` → ESO writes Secret `orders-api-secrets` → env var.

**What stops team-a from reading team-b's secrets?**
Three things: Kubernetes RBAC (team-a can't read Secrets in team-b), the Vault
role is bound to the team-a namespace, and the policy only covers team-a's path.

**What's an error budget? Why burn-rate alerts?**
99.5% over 30 days means 0.5% of requests can fail. Burn rate is how fast you
spend it: 1× = exactly on schedule, 14.4× = the whole month gone in ~2 days.
Paging on burn rate over two windows catches big outages fast and slow leaks
eventually, without paging on short blips. Explain the table in ADR 0004.

**Why `maxUnavailable: 0` and a preStop sleep?**
Rolling updates never reduce ready capacity. The preStop sleep covers the gap
between the pod being marked terminating and Envoy/kube-proxy removing it from
endpoints; without it, a few requests hit a pod that's already shutting down.
(Show the result of chaos experiment 2.)

**What happens if someone runs `kubectl edit` in the cluster?**
Flux detects drift on the next reconcile and restores Git's version. Show
experiment 3. The fix for a real change is a PR.

**How would this change on AKS?**
Entra ID groups as RBAC subjects, Workload Identity instead of Vault
Kubernetes auth (or Azure Key Vault provider in ESO), Azure CNI with Cilium for
NetworkPolicy, Managed Prometheus/Grafana optional, Terraform for AKS itself
plus Flux via the AKS GitOps extension or `flux_bootstrap_git`.

**What would you improve?**
Kyverno policies, canary releases gated on burn rate, Loki for logs, hard
NetworkPolicy permissions (see ADR 0002 trade-off), Vault HA with auto-unseal.

## Things to demo live (if asked to share screen)
1. `flux get kustomizations -A` – layers and order
2. `kubectl auth can-i` checks from the README
3. Grafana SLO dashboard during `make chaos-errors`
4. One postmortem you wrote

## Resume bullet (edit numbers after you run it)
- Built a multi-tenant Kubernetes platform (Terraform, FluxCD, Gateway API,
  Vault + External Secrets) with per-tenant RBAC, NetworkPolicy and Vault
  isolation, and availability/latency SLOs with multi-window burn-rate alerts
  (Prometheus, Sloth, Grafana); validated with N chaos experiments and postmortems.
