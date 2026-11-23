# ADR 0001: Flux over Argo CD

**Status:** accepted

## Context
The platform needs a GitOps controller that can reconcile infrastructure and
tenant apps from one repo, order layers explicitly, and keep tenants from
deploying outside their namespace.

## Options
- **Argo CD**: strong UI, ApplicationSets, AppProjects for tenancy. Tenancy is
  enforced by Argo's own RBAC layer, separate from Kubernetes RBAC.
- **Flux**: no UI, but every concept is a Kubernetes CRD. Tenancy uses plain
  Kubernetes RBAC through service-account impersonation.

## Decision
Flux. Tenant isolation is enforced by the API server itself
(`spec.serviceAccountName` on each tenant Kustomization), which is the same
model the rest of the platform already uses. `dependsOn` gives explicit
ordering. Image automation is built in. It is also what I run at work, so the
patterns carry over.

## Consequences
- No UI: status comes from `flux get`, Kubernetes events and Grafana.
- Cross-namespace source references are allowed so tenant Kustomizations can
  use the shared GitRepository. A stricter setup would run Flux with
  `--no-cross-namespace-refs` and give each tenant its own GitRepository.
