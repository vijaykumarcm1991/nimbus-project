# ROLLBACK.md — Nimbus rollback strategy

## Philosophy

Every deployment produces an immutable image tagged with the exact commit
SHA it was built from (plus a moving `latest` tag). "Rolling back" is not a
special procedure — it is a normal deployment of an older, known-good tag,
using the same `deploy.sh` as every deploy.

Two things can break in a bad deploy, and they have different remedies:

| What broke | Remedy | Speed |
|---|---|---|
| The application (code) | Redeploy the last known-good image tag | Minutes |
| The data (bad migration / corrupted rows) | Restore the Postgres volume from a backup | Slower; loses changes made after the backup |

Rolling back the application never touches data: Postgres data lives in the
`db_data` Docker volume, whose lifecycle is decoupled from the app image.

## 1. Application rollback (demonstrated)

### Find the last known-good version
- GitHub → repo → **Actions**: the last green run *before* the bad one; its
  commit SHA is the version to redeploy.
- Or GitHub → repo → **Packages** → `nimbus-project` → **Versions**: every
  pushed image, tagged by SHA.

### Roll back
```bash
./deploy.sh ghcr.io/vijaykumarcm1991/nimbus-project:<known-good-sha>
```

The script pulls that exact image, starts the stack, and refuses to report
success unless the app passes its own `/health` check (which verifies both
Postgres and Redis are reachable).

### Verify
```bash
docker compose -f docker-compose.deploy.yml ps   # IMAGE column shows the old SHA
curl -f http://localhost:8000/health
```

Worked example (performed 2026-09-15): deployed `:latest`, then rolled back
to `:62b29ce49225d5241df46104d41d355d49c5bf18`. The stack came up healthy on
the older image, and data shortened before the rollback was still served.

## 2. Data rollback

If a deploy corrupts the *data* (e.g. a bad migration), redeploying an older
image fixes nothing — the damage lives in the `db_data` volume. The remedy
is restore-from-backup.

### Take a backup (any time, stack running)
```bash
bash backup.sh          # writes backups/nimbus-db-<timestamp>.sql
```

### The disaster drill (data loss → restore)
```bash
# 1. Simulate data loss (DESTRUCTIVE — removes the db_data volume; the
#    backup file is your safety net. Verify it first:
#    ls -lh backups/ && grep -c "CREATE TABLE" backups/<file>.sql)
docker compose -f docker-compose.deploy.yml down -v

# 2. Start an empty database only, wait for (healthy)
docker compose -f docker-compose.deploy.yml up -d db
docker compose -f docker-compose.deploy.yml ps

# 3. Restore
bash restore.sh backups/nimbus-db-<timestamp>.sql

# 4. Bring up the rest of the stack and verify
docker compose -f docker-compose.deploy.yml up -d
curl -f http://localhost:8000/health    # then check old URLs at /docs
```

**Honest limitation:** a restore recovers the database *as of the backup*.
Anything written between the backup and the failure is lost — that window is
called the recovery point objective (RPO). Backup frequency is a trade-off
between storage cost and acceptable data loss.

## What I'd add with more time/budget

- Blue-green or canary deploys, so rollback is a traffic switch rather than
  a redeploy.
- Automated rollback: if the post-deploy health gate fails, redeploy the
  previous tag automatically.
- Scheduled backups shipped off-host (e.g. to S3) with retention, instead of
  manual on-host dumps.
