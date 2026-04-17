#!/usr/bin/env bash
set -eo pipefail

# Guards against misconfigured push/sign runs by asserting required values exist.
#
# Inputs (env vars):
#   IMAGE_REPOSITORY          – full image repository path
#   REGISTRY_HOST             – registry hostname
#   AWS_REGISTRY_ROLE_TO_ASSUME – IAM role ARN for the registry account

test -n "$IMAGE_REPOSITORY" \
  || { echo "Image repository could not be determined" >&2; exit 1; }

test -n "$AWS_REGISTRY_ROLE_TO_ASSUME" \
  || { echo "Provide aws_registry_role_to_assume, or registry_account_id with aws_registry_role_name, or secret AWS_REGISTRY_ROLE when pushing or signing" >&2; exit 1; }

test -n "$REGISTRY_HOST" \
  || { echo "A remote registry must be configured when push_image or sign_release is enabled" >&2; exit 1; }
