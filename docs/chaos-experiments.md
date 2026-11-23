# Chaos experiments

Write the hypothesis **before** running anything. Afterwards fill in
"Observed" with real numbers and screenshots, and turn anything surprising
into a postmortem. Run `make load` in another terminal for all of these.

---

## 1. Error injection burns the budget and pages

- **Hypothesis:** 20% HTTP 500s on team-a gives a burn rate of ~40× (0.20 / 0.005).
  The 14.4× fast-burn page alert fires after ~5 minutes (once both the 5m and
  1h windows exceed the threshold). team-b's SLO doesn't move.
- **Run:** `make chaos-errors`, wait 10 minutes, `make chaos-heal`
- **Watch:** burn-rate stat, Prometheus → Alerts, team-b panels
- **Observed:**
  - Time to alert:
  - Peak burn rate:
  - Budget consumed:
  - team-b affected? 
- **Follow-up questions:** How long after healing until the page alert resolves, and why? (hint: short window)

## 2. Pod kills under load

- **Hypothesis:** with 2 replicas, `maxUnavailable: 0`, readiness gating and a
  5s preStop drain, killing a pod every 20s causes zero 5xx and no SLO impact.
- **Run:** `make chaos-pods`
- **Observed:**
  - 5xx count during run:
  - k6 `http_req_failed`:
- **If you see errors:** try removing the preStop hook and re-run. The gap
  between the two runs is the reason it exists.

## 3. Manual change vs Git

- **Hypothesis:** a hand-edited HTTPRoute with a wrong backend port returns 5xx
  until Flux reconciles, then Git's version is restored without anyone touching it.
- **Run:** `make chaos-route`, curl through the Gateway, wait or `flux reconcile`
- **Observed:**
  - HTTPRoute condition and reason:
  - Time until Flux reverted it:

## 4. Vault unavailable

- **Hypothesis:** scaling Vault to 0 doesn't affect running pods (the Kubernetes
  Secret already exists). ExternalSecrets go `SecretSyncedError`, and
  `ExternalSecretNotSynced` fires after 10 minutes. New pods still start.
- **Run:** `kubectl -n vault scale statefulset vault --replicas=0`, wait 12 min,
  delete one app pod, then scale back to 1 and re-run `make vault-setup` (dev mode lost its data).
- **Observed:**

## 5. Latency injection vs the latency SLO

- **Hypothesis:** adding 400ms to every request on team-a breaches the 300ms
  SLO immediately (100% of requests are "bad") while the availability SLO stays at 100%.
- **Run:** `./scripts/chaos/inject-errors.sh team-a 0 400`, then `make chaos-heal`
- **Observed:**

## 6. Noisy neighbour

- **Hypothesis:** team-b scaling to 50 replicas is stopped by its ResourceQuota
  (`pods: 20`) and team-a's latency doesn't change.
- **Run:** `kubectl -n team-b scale deploy/orders-api --replicas=50` (Flux will
  revert this too), `kubectl -n team-b describe resourcequota`
- **Observed:**
