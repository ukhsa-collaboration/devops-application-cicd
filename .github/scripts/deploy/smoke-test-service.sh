#!/usr/bin/env bash
set -eo pipefail

# Performs a simple HTTP smoke test against a deployed service endpoint.
# Fails the step (and therefore the deployment) if the response code is not 200.
#
# Inputs (env vars):
#   URL – the endpoint to probe (must return HTTP 200)

USER_AGENT="Mozilla/5.0 (compatible; SmokeTest/1.0)"
code=$(curl -A "$USER_AGENT" -L -s -o /dev/null -w "%{http_code}" "$URL")

if [ "$code" -ne 200 ]; then
  echo "Smoke test failed with status $code for $URL" >&2
  exit 1
fi

echo "Smoke test succeeded for $URL"
