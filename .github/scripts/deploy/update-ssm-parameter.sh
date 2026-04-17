#!/usr/bin/env bash
set -eo pipefail

# Stores the immutable image reference in an SSM Parameter Store string parameter.
# Uses --overwrite so re-runs are idempotent.
#
# Inputs (env vars):
#   PARAMETER_NAME – SSM parameter path (e.g. /myapp/dev/image_tag)
#   IMAGE_URI      – immutable image reference to store

test -n "$PARAMETER_NAME" \
  || { echo "Parameter name missing" >&2; exit 1; }

aws ssm put-parameter \
  --name "$PARAMETER_NAME" \
  --type "String" \
  --value "$IMAGE_URI" \
  --overwrite
