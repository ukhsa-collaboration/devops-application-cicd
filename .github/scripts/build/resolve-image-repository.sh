#!/usr/bin/env bash
set -eo pipefail

# Inputs (env vars):
#   REGISTRY_HOSTNAME   – explicit registry host (overrides account-ID-based derivation)
#   REGISTRY_ACCOUNT_ID – AWS account ID; used to derive the ECR hostname when REGISTRY_HOSTNAME is absent
#   AWS_REGION          – AWS region (workflow-level env)
#   ECR_NAMESPACE       – ECR namespace (workflow-level env, defaults to service_identifier)
#   APP_NAME            – application name (workflow-level env)
#
# Outputs (appended to GITHUB_OUTPUT):
#   registry_host     – resolved registry hostname (may be empty for local/no-push builds)
#   image_repository  – full image repository path

if [ -n "$REGISTRY_HOSTNAME" ]; then
  registry_host="$REGISTRY_HOSTNAME"
elif [ -n "$REGISTRY_ACCOUNT_ID" ]; then
  registry_host="${REGISTRY_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
else
  registry_host=""
fi

repository_path="${ECR_NAMESPACE}/${APP_NAME}"
if [ -n "$registry_host" ]; then
  image_repository="${registry_host}/${repository_path}"
else
  image_repository="${repository_path}"
fi

{
  echo "registry_host=${registry_host}"
  echo "image_repository=${image_repository}"
} >> "$GITHUB_OUTPUT"
