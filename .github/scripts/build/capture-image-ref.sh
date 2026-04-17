#!/usr/bin/env bash
set -eo pipefail

# Extracts the primary image tag from the docker/metadata-action output and
# derives a short tag suffix for use as the application version.
#
# Inputs (env vars):
#   META_TAGS – newline-delimited list of image tags produced by docker/metadata-action
#
# Outputs (appended to GITHUB_OUTPUT):
#   image_ref – full primary image reference (first tag)
#   image_tag – tag portion of the primary reference (everything after the last ':')

primary_tag=$(printf '%s\n' "$META_TAGS" | head -n 1)
echo "image_ref=${primary_tag}" >> "$GITHUB_OUTPUT"
echo "image_tag=${primary_tag##*:}" >> "$GITHUB_OUTPUT"
