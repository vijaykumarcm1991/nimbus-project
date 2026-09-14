# Nimbus — Engineering Notes & Trade-offs

Postmortem-style notes: known limitations, deliberate trade-offs, and what
I'd improve with more time/budget.

## The flaky test (deliberately introduced and handled)

I introduced a deliberately flaky test (`test_flaky_example`) that failed
~20% of the time because it depended on `random.random()` — a
non-deterministic value. Running it repeatedly showed inconsistent
pass/fail results with no code change.

**How I handled it:** I fixed the root cause rather than papering over it.
Seeding the generator (`random.seed(42)`) made the test deterministic, so
it now passes 100% of the time. I considered the alternatives — auto-retry
and quarantining — and noted these are valid stopgaps for tests that are
flaky for *unavoidable* external reasons (e.g. network), but a
deterministic fix is preferable when the flakiness is in your control.

## Deliberate trade-offs (limitations I'm aware of)

- **Integration tests over unit tests:** tests hit the running stack over
  HTTP rather than testing functions in isolation. This tests the real
  system end-to-end, but is slower and needs the stack running. With more
  time I'd add isolated unit tests too.
- **DynamoDB in IaC vs Postgres in the app:** the Terraform provisions a
  DynamoDB table to demonstrate IaC, while the app itself uses Postgres via
  Docker Compose. In a real cloud deploy I'd provision RDS (Postgres) and
  wire the app to it.
- **Broad exception handling:** the DB-retry loop and healthcheck catch
  broad exceptions intentionally (documented in ruff.toml via ignoring
  BLE001) — acceptable for resilience code, flagged here for honesty.
- **Retry loop kept as a fallback:** healthchecks + `condition:
  service_healthy` handle startup ordering, but I kept the app's DB-retry
  loop as belt-and-suspenders.
- **.terraform.lock.hcl gitignored:** teams often commit this to pin
  provider versions; ignored here since state is local/ephemeral. A
  judgment call.

## Known gaps I have NOT yet fixed

- Secrets: the Postgres password is currently in plain text in
  docker-compose.yml (to be addressed in Task 4).