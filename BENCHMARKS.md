# BENCHMARKS.md

Tracks performance of v2 hot paths. Updated when a `colbert:smoke_test` (or any
phase-specific benchmark) reports a step exceeding its budget.

Budgets are documented in `handoff/v2/04_IMPLEMENTATION_PLAN.md`. The acceptance
gate is: **no step in `colbert:smoke_test` exceeds 5 seconds on the production
box.**

## phase-7-smoke

Source: `bundle exec rake colbert:smoke_test`. Run after each backend deploy.

| Date | Box | doc create (ms) | embed_chunk (ms) | insert_chunk (ms) | score (ms) | Notes |
|---|---|---|---|---|---|---|
| 2026-05-27 | dev (Ubuntu 24.04, 4.7 GB) | 846 | 479 | 29 | 95 | Cold sidecar; first encode is slow (model warm-up). All steps < 5s. |

A row here with **any cell ≥ 5000** is the signal to widen the budget or to
investigate. Likely first culprits: HTTP timeout / GC / cold model load (mitigate
with a sidecar warmer that runs `/embed_chunk` once at boot).

## Other benchmarks

(Reserved for future phases — atom extraction throughput, decay job duration,
end-to-end chat latency, etc.)
