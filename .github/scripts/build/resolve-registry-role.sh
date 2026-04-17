#!/usr/bin/env bash
set -eo pipefail

# Resolves the IAM role ARN to assume for central ECR access.
#
# Inputs (env vars):
#   REGISTRY_ROLE_ARN    – explicit full ARN (highest priority)
#   REGISTRY_ACCOUNT_ID  – AWS account ID; combined with REGISTRY_ROLE_NAME to derive the ARN
#   REGISTRY_ROLE_NAME   – IAM role name in the registry account
#   REGISTRY_ROLE_SECRET – fallback ARN from the caller's secret
#
# Output (appended to GITHUB_OUTPUT):
#   value – resolved IAM role ARN (may be empty if no push/sign is needed)

role_to_assume="$REGISTRY_ROLE_ARN"

if [ -z "$role_to_assume" ] && [ -n "$REGISTRY_ACCOUNT_ID" ] && [ -n "$REGISTRY_ROLE_NAME" ]; then
  role_to_assume="arn:aws:iam::${REGISTRY_ACCOUNT_ID}:role/${REGISTRY_ROLE_NAME}"
fi

if [ -z "$role_to_assume" ] && [ -n "$REGISTRY_ROLE_SECRET" ]; then
  role_to_assume="$REGISTRY_ROLE_SECRET"
fi

echo "value=${role_to_assume}" >> "$GITHUB_OUTPUT"
