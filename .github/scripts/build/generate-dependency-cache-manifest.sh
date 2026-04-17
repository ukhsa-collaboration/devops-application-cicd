#!/usr/bin/env bash
set -eo pipefail

# Generates a deterministic manifest describing Python dependency inputs.
# The workflow hashes this file to build a cache key aligned with install behavior.
#
# Inputs (env vars):
#   PIP_EXTRAS               - Optional extras passed to package install.
#   DOCKER_CONTEXT           - Docker build context.
#   DEPENDENCY_MANIFEST_PATH - Output file path.

manifest_path="${DEPENDENCY_MANIFEST_PATH:-.github/.cache/python-deps-manifest.txt}"
docker_context="${DOCKER_CONTEXT:-.}"
pip_extras="${PIP_EXTRAS:-}"

mkdir -p "$(dirname "$manifest_path")"

append_file_hash() {
  local file_path="$1"

  if [ -f "$file_path" ]; then
    printf 'file:%s sha256:%s\n' "$file_path" "$(sha256sum "$file_path" | awk '{print $1}')" >> "$manifest_path"
  fi
}

{
  printf 'schema:v1\n'
  printf 'python_version:%s\n' "$(python -VV 2>&1 | tr '\n' ' ')"
  printf 'pip_extras:%s\n' "$pip_extras"
  printf 'docker_context:%s\n' "$docker_context"
} > "$manifest_path"

install_target=""
if [ -f pyproject.toml ]; then
  install_target="."
elif [ -n "$docker_context" ] && [ -f "$docker_context/pyproject.toml" ]; then
  install_target="$docker_context"
fi

printf 'install_target:%s\n' "$install_target" >> "$manifest_path"

if [ -n "$install_target" ]; then
  if [ "$install_target" = "." ]; then
    append_file_hash "pyproject.toml"
    append_file_hash "uv.lock"
    append_file_hash "poetry.lock"
  else
    append_file_hash "$install_target/pyproject.toml"
    append_file_hash "$install_target/uv.lock"
    append_file_hash "$install_target/poetry.lock"
  fi
fi

append_file_hash "requirements.txt"
append_file_hash "requirements-dev.txt"

if [ "$docker_context" != "." ]; then
  append_file_hash "$docker_context/requirements.txt"
  append_file_hash "$docker_context/requirements-dev.txt"
fi
