# Native entry point. Git filtering excludes untracked credentials.
# nix eval --impure --json --file tests/family-apps.nix
import ./family-apps-checks.nix (builtins.getFlake ("git+file://" + toString ../.))
