#!/usr/bin/env bash
# deploy.sh — Deploy a specific Nimbus image to a staging host.
#
# Usage:  ./deploy.sh <image-tag>
# Example: ./deploy.sh ghcr.io/vijaykumarcm1991/nimbus-project:latest
#
# This script pulls a specific, versioned image from the registry and runs
# the full stack on the target host. It is run on-demand against a live
# staging environment (our sandbox is ephemeral, so deploy is manual by design).

set -euo pipefail   # fail fast: stop on any error, undefined var, or failed pipe

IMAGE_TAG="${1:-ghcr.io/vijaykumarcm1991/nimbus-project:latest}"

echo "==> Deploying image: ${IMAGE_TAG}"

# 1. Pull the exact image we want to deploy
echo "==> Pulling image from registry..."
docker pull "${IMAGE_TAG}"

# 2. Point compose at this specific image and (re)start the stack
echo "==> Starting the stack with the new image..."
APP_IMAGE="${IMAGE_TAG}" docker compose -f docker-compose.deploy.yml up -d

# 3. Wait for health, then verify
echo "==> Waiting for the app to become healthy..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:8000/health > /dev/null; then
    echo "==> Deploy successful — app is healthy."
    exit 0
  fi
  echo "    ...waiting ($i)"
  sleep 2
done

echo "!! Deploy failed — app did not become healthy in time."
exit 1