#!/usr/bin/env bash
set -eo pipefail

# Runs a caller-supplied command against the built container image to verify it
# starts and behaves as expected. For build-only runs the image is already loaded
# into the local daemon; for pushed images it is pulled first.
#
# Inputs (env vars):
#   IMAGE_UNDER_TEST            – full image reference (tag or digest)
#   CONTAINER_SMOKE_TEST_COMMAND – shell command to execute; IMAGE_UNDER_TEST is available
#   PUSH_IMAGE                  – "true" if the image was pushed (triggers a pull before run)

test -n "$IMAGE_UNDER_TEST" \
  || { echo "Image reference could not be determined for smoke testing" >&2; exit 1; }

test -n "$CONTAINER_SMOKE_TEST_COMMAND" \
  || { echo "container_smoke_test_command must not be empty when run_container_smoke_test is enabled" >&2; exit 1; }

if [ "$PUSH_IMAGE" = "true" ]; then
  docker pull "$IMAGE_UNDER_TEST"
else
  docker image inspect "$IMAGE_UNDER_TEST" >/dev/null
fi

bash -eo pipefail -c "$CONTAINER_SMOKE_TEST_COMMAND"
