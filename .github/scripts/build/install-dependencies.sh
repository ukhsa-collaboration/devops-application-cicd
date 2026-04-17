#!/usr/bin/env bash
set -eo pipefail

# Installs project dependencies for the test run.
# Prefers pyproject.toml (with optional extras via uv), falls back to requirements files.
#
# Inputs (env vars):
#   PIP_EXTRAS     – PEP 508 extras to install (e.g. "dev"); may be empty
#   DOCKER_CONTEXT – Docker build context directory; checked for pyproject.toml when none
#                    exists at the workspace root
#
# Cache directories:
#   PIP_CACHE_DIR defaults to .cache/pip
#   UV_CACHE_DIR defaults to .cache/uv

export PIP_CACHE_DIR="${PIP_CACHE_DIR:-.cache/pip}"
export UV_CACHE_DIR="${UV_CACHE_DIR:-.cache/uv}"
mkdir -p "$PIP_CACHE_DIR" "$UV_CACHE_DIR"

python -m pip install --upgrade pip

install_target=""
if [ -f pyproject.toml ]; then
  install_target="."
elif [ -n "$DOCKER_CONTEXT" ] && [ -f "$DOCKER_CONTEXT/pyproject.toml" ]; then
  install_target="$DOCKER_CONTEXT"
fi

if [ -n "$install_target" ]; then
  python -m pip install --upgrade uv
  if [ -n "$PIP_EXTRAS" ]; then
    uv pip install --system "${install_target}[${PIP_EXTRAS}]" \
      || uv pip install --system "$install_target" \
      || python -m pip install "${install_target}[${PIP_EXTRAS}]" \
      || python -m pip install "$install_target"
  else
    uv pip install --system "$install_target" \
      || python -m pip install "$install_target"
  fi
fi

if [ -f requirements.txt ]; then
  python -m pip install -r requirements.txt
  if [ -f requirements-dev.txt ]; then
    python -m pip install -r requirements-dev.txt
  fi
fi

if [ -n "$DOCKER_CONTEXT" ] && [ "$DOCKER_CONTEXT" != "." ] && [ -f "$DOCKER_CONTEXT/requirements.txt" ]; then
  python -m pip install -r "$DOCKER_CONTEXT/requirements.txt"
  if [ -f "$DOCKER_CONTEXT/requirements-dev.txt" ]; then
    python -m pip install -r "$DOCKER_CONTEXT/requirements-dev.txt"
  fi
fi
