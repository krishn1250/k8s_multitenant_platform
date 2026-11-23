# Postmortem: <short title>

**Date:** YYYY-MM-DD · **Author:** · **Status:** draft / final
**Severity:** · **Duration:** (detected → resolved)
**Error budget consumed:** __% of the 30-day budget (from the SLO dashboard)

## Summary
Two or three sentences: what broke, who was affected, how it was fixed.

## Impact
Requests failed, latency added, tenants affected. Use numbers from Grafana.

## Timeline (all times local)
| Time | Event |
|---|---|
| | change made / fault injected |
| | first symptom visible on dashboard |
| | alert fired (which one, which severity) |
| | started investigating |
| | root cause found |
| | mitigated |
| | fully resolved |

## Detection
How was it noticed? Did the right alert fire at the right severity? How long
between the cause and the alert, and was that acceptable?

## Root cause
The actual mechanism, not "human error". Use "5 whys" if it helps.

## What went well
## What went badly
## Where we got lucky

## Action items
| Action | Type (prevent / detect / mitigate) | Owner | Status |
|---|---|---|---|

*Blameless: focus on how the system allowed this, not on who did it.*
