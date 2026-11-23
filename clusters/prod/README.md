# prod

Same layout as `dev`; `ENV: prod` in tenants.yaml points tenant apps at `overlays/prod` (3 replicas, HPA,
stricter resources). Bootstrap it with `make up ENV=prod CLUSTER=platform-prod`.

Promotion is a pull request that changes the image tag in
`apps/orders-api/k8s/overlays/prod/kustomization.yaml`.
