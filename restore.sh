#!/usr/bin/env bash
# restore.sh — restore the Postgres data volume from a backup SQL file.
# Usage:  bash restore.sh backups/nimbus-db-<timestamp>.sql
# Run AFTER starting a fresh, empty db container (see ROLLBACK.md drill):
#   docker compose -f docker-compose.deploy.yml up -d db

set -euo pipefail

COMPOSE="docker compose -f docker-compose.deploy.yml"
FILE="${1:?Usage: restore.sh <backup-file>}"
[ -f "${FILE}" ] || { echo "!! Backup file not found: ${FILE}"; exit 1; }

echo "==> Waiting for the database to accept connections..."
until ${COMPOSE} exec -T db pg_isready -U postgres > /dev/null 2>&1; do
  sleep 2
done

echo "==> Restoring from ${FILE}"
${COMPOSE} exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < "${FILE}"

echo "==> Restore complete. Bring up the rest of the stack and verify:"
echo "    docker compose -f docker-compose.deploy.yml up -d"
