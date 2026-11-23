# ADR 0002: Tenant isolation model

**Status:** accepted

## Context
Several teams share one cluster. A mistake or compromise in one tenant must
not affect another tenant's availability, data or secrets.

## Decision
Soft multi-tenancy, namespace per tenant, with these layers:

| Layer | Control | Owner |
|---|---|---|
| API access | RoleBinding of `edit` to the tenant's group; `view` for on-call | platform |
| Deploy identity | Flux impersonates `flux-reconciler` SA bound to `tenant-deployer` | platform |
| Pods | Pod Security Admission `restricted` (non-root, no privilege escalation, seccomp) | platform |
| Network | default-deny ingress + egress; allow DNS, Gateway → app, Prometheus → app | platform |
| Capacity | ResourceQuota + LimitRange defaults | platform |
| Ingress | Gateway accepts routes only from `platform.io/tenant=true` namespaces | platform |
| Secrets | Vault role + policy per tenant, scoped to `tenants/data/<tenant>/*` | platform |

Everything in the "platform" column lives in `tenants/` and `infrastructure/`
and is applied with Flux's own identity, so tenants can't change it.

## Trade-offs
- `tenant-deployer` aggregates the built-in `edit` rules, which include
  NetworkPolicy. Allows are additive, so a tenant could widen its own ingress.
  Fix: replace aggregation with an explicit rule list, or enforce with Kyverno.
- Soft tenancy shares the kernel and control plane. Hostile tenants would need
  node pools per tenant or separate clusters.
