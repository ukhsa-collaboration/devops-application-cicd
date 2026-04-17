#!/usr/bin/env bash
set -eo pipefail

# Runs Hadolint against the Dockerfile passed via the DOCKERFILE env var.
#
# Inputs (env vars):
#   DOCKERFILE – path to the Dockerfile relative to the workspace root

test -f "$DOCKERFILE" \
  || { echo "Dockerfile '$DOCKERFILE' not found" >&2; exit 1; }

docker run --rm -i hadolint/hadolint:2.12.0 hadolint - < "$DOCKERFILE"
