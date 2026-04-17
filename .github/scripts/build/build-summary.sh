#!/usr/bin/env bash
set -eo pipefail

# Generates a markdown summary table of the build job outcomes and appends it to
# both a local file (for PR comment re-use) and GITHUB_STEP_SUMMARY.
#
# Inputs (env vars):
#   HADOLINT_OUTCOME        – outcome of the Dockerfile lint step
#   UNIT_OUTCOME            – outcome of the unit test step
#   INT_OUTCOME             – outcome of the integration test step
#   CONTAINER_SMOKE_OUTCOME – outcome of the container smoke test step
#   BUILD_OUTCOME           – outcome of the docker build step
#   PUSH_IMAGE              – "true" when the image was pushed to the registry
#   IMAGE_REF               – primary tagged image reference
#   IMMUTABLE_IMAGE         – digest-pinned image reference (may be empty)
#   SUMMARY_FILE            – path of the output file (defaults to ci-summary.md)

SUMMARY_FILE="${SUMMARY_FILE:-ci-summary.md}"

{
  echo "### Container Image Build"
  echo "| Check | Result |"
  echo "| --- | --- |"
  echo "| Dockerfile lint | ${HADOLINT_OUTCOME} |"
  echo "| Unit tests | ${UNIT_OUTCOME} |"
  echo "| Integration tests | ${INT_OUTCOME} |"
  echo "| Container smoke test | ${CONTAINER_SMOKE_OUTCOME} |"
  if [ "$PUSH_IMAGE" = "true" ] && [ "$BUILD_OUTCOME" = "success" ]; then
    echo ""
    echo "**Image:** \`${IMAGE_REF}\`"
    if [ -n "$IMMUTABLE_IMAGE" ]; then
      echo ""
      echo "**Immutable image:** \`${IMMUTABLE_IMAGE}\`"
    fi
  fi
} > "$SUMMARY_FILE"

cat "$SUMMARY_FILE" >> "$GITHUB_STEP_SUMMARY"
