#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
image="${NIX_DOCKER_IMAGE:-nixos/nix:latest}"
platform="${NIX_DOCKER_PLATFORM:-linux/amd64}"

exec docker run --rm \
  --platform "${platform}" \
  --mount "type=bind,src=${repo_root},dst=/workspace,readonly" \
  --workdir /workspace \
  --env "NIX_CONFIG=experimental-features = nix-command flakes" \
  "${image}" \
  nix flake check --no-build "$@"
