#!/usr/bin/env bash
set -eo pipefail

# Guards the deploy job by asserting required values exist before any AWS calls.
#
# Inputs (env vars):
#   IMAGE_URI      – immutable image reference to deploy
#   ROLE_TO_ASSUME – IAM role ARN to assume for this environment

test -n "$IMAGE_URI" \
  || { echo "immutable_image is required" >&2; exit 1; }

test -n "$ROLE_TO_ASSUME" \
  || { echo "Deployment role is required via aws_role_to_assume or secret AWS_DEPLOY_ROLE" >&2; exit 1; }
