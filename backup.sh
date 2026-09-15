#!/usr/bin/env bash
# backup.sh — dump the Postgres data volume to a timestamped SQL file.
# Usage:  bash backup.sh        (run from the Nimbus root, stack running)
# Uses the db container's own credentials (POSTGRES_USER/POSTGRES_DB are set
# inside the container by compose) — no secrets in this script.

set -euo pipefail

COMPOSE="docker compose -f docker-compose.deploy.yml"
OUT="backups/nimbus-db-$(date +%Y%m%d-%H%M%S).sql"

mkdir -p backups

echo "==> Dumping database to ${OUT}"
${COMPOSE} exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' > "${OUT}"

echo "==> Done. Verify it before trusting it:"
echo "    ls -lh ${OUT} && grep -c CREATE TABLE ${OUT}"
