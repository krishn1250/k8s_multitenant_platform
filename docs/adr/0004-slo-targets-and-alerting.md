# ADR 0004: SLO targets and burn-rate alerting

**Status:** accepted

## SLIs and targets (30-day rolling window)

| SLO | SLI | Target | Budget |
|---|---|---|---|
| Availability | non-5xx requests / all requests | 99.5% | 0.5% ≈ 3.6 h of full outage |
| Latency | requests < 300 ms / all requests | 99% | 1% of requests may be slower |

Measured at the app (server side) from `http_requests_total` and
`http_request_duration_seconds`. Health and metrics endpoints are excluded so
probes don't inflate the numbers.

## Why these numbers
99.5% is achievable on a 2-replica service on a laptop cluster and still tight
enough that a bad deploy shows up. 300 ms sits well above normal p99 (~20 ms)
so the latency SLO catches real degradation, not noise.

## Alerting
Alerting on raw error rate is either noisy or slow. Sloth generates the
multi-window, multi-burn-rate alerts from the Google SRE Workbook:

| Severity | Burn rate | Long window | Short window | Budget spent when it fires |
|---|---|---|---|---|
| page | 14.4× | 1h | 5m | 2% |
| page | 6× | 6h | 30m | 5% |
| ticket | 3× | 1d | 2h | 10% |
| ticket | 1× | 3d | 6h | 10% |

The short window makes alerts reset quickly once the problem is fixed.

## Error budget policy (what the numbers are for)
- Budget > 50%: ship freely.
- Budget 0-50%: one change at a time, rollback ready.
- Budget exhausted: feature deploys pause; only reliability fixes ship until
  the budget recovers.
