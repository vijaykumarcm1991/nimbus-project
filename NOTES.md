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

## Deployment approach (and the ephemeral-environment trade-off)

The CI pipeline fully automates: lint → test (gating) → build image →
push to GHCR, tagged with the commit SHA and `latest`.

The **deploy step is deliberately manual/scripted** rather than automated,
because the staging environment (a KodeKloud AWS sandbox) is ephemeral —
it resets every ~3 hours and issues fresh temporary credentials each
session. There is no permanent host or stable long-lived credential to
give the pipeline, so auto-deploy on every push isn't safe or meaningful
here.

Instead, deployment is a single scripted command run on-demand against a
live environment:

    ./deploy.sh ghcr.io/vijaykumarcm1991/nimbus-project:<tag>

The script pulls a specific tested image and runs the full stack via
`docker-compose.deploy.yml`, then verifies health before reporting success.

**With more time/budget**, I'd provision a permanent staging host (e.g. a
small always-on instance or a managed container service), store deploy
credentials as GitHub Actions secrets, and add an automated deploy job
gated behind the build step — making the whole push-to-live flow automatic.

## Secrets & configuration approach

Secrets are kept out of the repo and out of image layers at every stage:

- **Local dev:** secrets live in a gitignored `.env` file; `docker-compose`
  loads it automatically. A committed `.env.example` documents required
  config with placeholder values only.
- **Git:** `.gitignore` blocks `.env`, `*.tfstate`, and `*.tfstate.*`
  (Terraform state can contain secrets in plain text).
- **Docker images:** `.dockerignore` blocks `.env` so secrets can never be
  baked into an image layer.
- **CI/CD:** the pipeline authenticates to GHCR using GitHub's
  auto-generated, short-lived `GITHUB_TOKEN` — no long-lived registry
  credentials are stored anywhere. The job requests only `packages: write`
  (least privilege).
- **Cloud (Terraform):** AWS credentials are supplied via environment
  variables in the shell session only — never written to any file.

### What I'd do for production (with more time/budget)

- Use a dedicated **secrets manager / vault** (e.g. AWS Secrets Manager or
  HashiCorp Vault) so secrets are centrally managed, rotated, and audited
  rather than living in `.env` files.
- Inject secrets at runtime from the manager rather than via env files.
- Apply least-privilege IAM roles for each component instead of broad
  credentials.
- Remove the fallback password default from compose entirely.

## CI secrets handling

CI can't read the local `.env` (it's gitignored, by design), so test-stage
config is provided via an `env:` block in the workflow. These are
**throwaway, test-only** credentials for an ephemeral Postgres container
that never holds real data. For any *real* secret, I'd use **GitHub Actions
Secrets** (encrypted, referenced as `${{ secrets.NAME }}`) rather than
inline values — the same "each environment supplies secrets its own way"
principle.