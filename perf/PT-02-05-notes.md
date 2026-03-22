## PT-02 — API Response Time Under Load

- **JMeter plan:** `perf/rems_api_mixed_load.jmx` (see `perf/README.md` to run).
- Target: ~100 concurrent virtual users (50 + 30 + 20 thread groups).
- Mix of operations:
  - 50% `GET /api/v1/units?available_only=true`
  - 20% `POST /api/v1/appointments`
  - 30% `GET /api/v1/invoices`
- NFR thresholds:
  - p95 < 500 ms
  - p99 < 2000 ms
  - Error rate < 5%.

## PT-04 — Concurrent Viewing Booking (Race Condition)

- **JMeter plan:** `perf/rems_viewing_race_condition.jmx`.
- Scenario:
  - 20 virtual users send `POST /api/v1/appointments` for the **same** `unit_id` and `scheduled_time` within a 1-second window.
  - Assert:
    - Exactly one request returns success (201/200).
    - All others return 409 Conflict.
    - No duplicate appointment rows exist in the database for that slot.

## PT-05 — Search Performance with Complex Filters

- **JMeter plan:** `perf/rems_units_search_load.jmx`.
- Scenario:
  - Populate database with at least 10,000 units of varied price, size, availability, and classification tier.
  - JMeter sends `GET /api/v1/units` with multiple query params (price range, size, availability, tier).
  - Run with 50 concurrent users performing different searches.
- NFR thresholds:
  - Single query completes in < 200 ms.
  - 50 concurrent searches maintain < 500 ms p95.
  - No full table scans (verify via database EXPLAIN or monitoring).

