#!/usr/bin/env bash
set -eo pipefail

# Writes the immutable (digest-pinned) image reference to GITHUB_OUTPUT.
#
# Inputs (env vars):
#   IMAGE_REPOSITORY – registry + namespace + name, without tag or digest
#   IMAGE_DIGEST     – digest produced by docker/build-push-action (e.g. sha256:abc...)
#
# Output (appended to GITHUB_OUTPUT):
#   value – full immutable reference in the form <repository>@<digest>

echo "value=${IMAGE_REPOSITORY}@${IMAGE_DIGEST}" >> "$GITHUB_OUTPUT"
