#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
image="${NIX_DOCKER_IMAGE:-nixos/nix:latest}"
platform="${NIX_DOCKER_PLATFORM:-linux/amd64}"
mode=check
case "${1:-}" in
  --full)
    mode=full
    shift
    if (( $# )); then
      printf '%s\n' '--full accepts no additional arguments; all stages use the locked homelab configuration.' >&2
      exit 2
    fi
    ;;
  --help|-h)
    printf '%s\n' \
      'Usage: check-flake-docker.sh [NIX_FLAKE_CHECK_ARGUMENTS...]' \
      '       check-flake-docker.sh --full' \
      'Default: flake check without building.' \
      '--full: flake check, Compose/maintenance tests, host invariants, homelab build.' \
      'All Nix operations run in Docker. Nothing is deployed or activated.'
    exit 0
    ;;
esac

# Match Git-flake filtering while including staged additions and working-tree
# edits. Refuse to silently omit new Nix modules referenced by existing files.
untracked_nix="$(git -C "${repo_root}" ls-files --others --exclude-standard -- '*.nix')"
if [[ -n "${untracked_nix}" ]]; then
  printf 'Untracked Nix files would be excluded from the check:\n%s\n' "${untracked_nix}" >&2
  printf 'Stage only the intended Nix files with git add, then retry. No commit is required.\n' >&2
  exit 2
fi

# A bind-mounted checkout retains host ownership, which libgit2 rejects when
# Nix runs as container root. Stream only indexed paths into a disposable,
# container-owned directory instead. Never copy .git or untracked credentials,
# change host ownership, or disable Git ownership checks with safe.directory.
git -C "${repo_root}" ls-files --cached --deduplicate -z |
  {
    paths=()
    while IFS= read -r -d '' path; do
      # tar preserves a leaf symlink, but follows symlinked parent directories.
      # Refuse those before streaming any paths to avoid copying external data.
      parent="${path%/*}"
      if [[ "${parent}" != "${path}" ]]; then
        while :; do
          if [[ -L "${repo_root}/${parent}" ]]; then
            printf 'Refusing symlinked parent of indexed path: %s\n' "${path}" >&2
            exit 1
          fi
          [[ "${parent}" == */* ]] || break
          parent="${parent%/*}"
        done
      fi
      if [[ -L "${repo_root}/${path}" || -f "${repo_root}/${path}" ]]; then
        paths+=("${path}")
      elif [[ -e "${repo_root}/${path}" ]]; then
        printf 'Unsupported indexed path (e.g. submodule): %s\n' "${path}" >&2
        exit 1
      fi
      # Absent indexed files represent unstaged deletions: omit them.
    done
    if (( ${#paths[@]} )); then
      printf '%s\0' "${paths[@]}"
    fi
  } |
  tar -C "${repo_root}" --null --no-recursion -T - -cf - |
  docker run --rm -i \
  --platform "${platform}" \
  --workdir /workspace \
  --env "NIX_CONFIG=experimental-features = nix-command flakes" \
  "${image}" \
  sh -eu -c '
    mode="$1"
    shift
    tar -xf -
    if [ "$mode" = check ]; then
      exec nix flake check --no-build --no-write-lock-file path:/workspace "$@"
    fi
    printf "%s\n" "[1/4] Flake evaluation"
    nix flake check --no-build --no-write-lock-file path:/workspace
    printf "%s\n" "[2/4] Compose and maintenance regression tests"
    nix shell --impure --no-write-lock-file --expr '\''
      let
        flake = builtins.getFlake "path:/workspace";
        pkgs = flake.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
      in pkgs.python3.withPackages (p: [ p.pyyaml ])
    '\'' --command python3 -B -m unittest discover -s tests -p "test_*.py" -v
    printf "%s\n" "[3/4] Family host invariants"
    nix eval --impure --json --no-write-lock-file --expr '\''
      import /workspace/tests/family-apps-checks.nix
        (builtins.getFlake "path:/workspace")
    '\''
    printf "\n%s\n" "[4/4] Homelab system build (no activation)"
    nix build --no-link --no-write-lock-file \
      path:/workspace#nixosConfigurations.homelab.config.system.build.toplevel
    printf "%s\n" "All four stages passed. No deployment or application runtime test was performed."
  ' check-flake "${mode}" "$@"
