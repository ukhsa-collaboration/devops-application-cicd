#!/usr/bin/env bash
set -eo pipefail

# Appends a per-environment deployment summary block to GITHUB_STEP_SUMMARY.
#
# Inputs (env vars):
#   DEPLOY_ENVIRONMENT – name of the deployment environment
#   DEPLOY_IMAGE       – immutable image reference that was deployed
#   SMOKE_TEST_URL     – smoke test endpoint (may be empty)

{
  echo "### Deployment (${DEPLOY_ENVIRONMENT})"
  echo "Environment: ${DEPLOY_ENVIRONMENT}"
  echo "Image: ${DEPLOY_IMAGE}"
  if [ -n "${SMOKE_TEST_URL}" ]; then
    echo "Smoke test: ${SMOKE_TEST_URL}"
  fi
} >> "$GITHUB_STEP_SUMMARY"
