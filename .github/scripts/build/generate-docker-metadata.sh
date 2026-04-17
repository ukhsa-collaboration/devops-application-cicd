#!/usr/bin/env bash
set -eo pipefail

# Generates minimal docker metadata for local act runs, where docker/metadata-action
# cannot rely on GitHub-provided credentials. The output shape matches the action's
# tags/labels outputs closely enough for downstream build steps.
#
# Inputs (env vars):
#   IMAGE_REPOSITORY – full image repository path
#   GITHUB_SHA       – commit SHA used to derive the primary sha tag
#   GITHUB_REPOSITORY – owner/repo identifier for OCI labels
#   RELEASE_TAG      – optional release tag to append
#
# Outputs (appended to GITHUB_OUTPUT):
#   tags   – newline-delimited list of image tags
#   labels – newline-delimited list of OCI labels

short_sha=$(printf '%s' "$GITHUB_SHA" | cut -c1-7)
primary_tag="${IMAGE_REPOSITORY}:sha-${short_sha}"

{
  echo "tags<<EOF"
  echo "$primary_tag"
  if [ -n "$RELEASE_TAG" ]; then
    echo "${IMAGE_REPOSITORY}:${RELEASE_TAG}"
  fi
  echo "EOF"
  echo "labels<<EOF"
  echo "org.opencontainers.image.source=${GITHUB_REPOSITORY}"
  echo "org.opencontainers.image.revision=${GITHUB_SHA}"
  echo "EOF"
} >> "$GITHUB_OUTPUT"
