#!/usr/bin/env bash
set -eo pipefail

# Picks the application version: the explicit release tag when present, otherwise
# the short SHA-based image tag.
#
# Inputs (env vars):
#   RELEASE_TAG – caller-supplied release tag (may be empty)
#   DEFAULT_TAG – fallback tag derived from the image reference (e.g. sha-abc1234)
#
# Output (appended to GITHUB_OUTPUT):
#   value – resolved application version string

if [ -n "$RELEASE_TAG" ]; then
  echo "value=$RELEASE_TAG" >> "$GITHUB_OUTPUT"
else
  echo "value=$DEFAULT_TAG" >> "$GITHUB_OUTPUT"
fi
