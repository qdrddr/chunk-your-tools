# Development guide

## Repository layout

```text
./   # Rust core + CLI
sdk/python/                  # PyPI chunk-your-tools
sdk/typescript/              # npm chunk-your-tools
sdk/go/                      # Go module
sdk/c/                       # C FFI + CMake
sdk/e2e/                     # Published-package smoke tests
scripts/
  local/dev/                 # local workflow (workflow.sh, helpers.sh)
  local/tests/               # local test helpers (all-fallow.sh)
  legal/                     # license audits + policy sync
  deps/                      # lockfile / pin verification
  pre-commit-hooks/          # prek hooks, C/Go SDK pre-commit runners
  publish/                   # sync-version, publish-git, registry helpers
  lib/                       # shared helpers (shorten-paths.sh)
```

## Local workflow

```bash
# Full check
./scripts/local/dev/workflow.sh all

# Rust only
./scripts/local/dev/workflow.sh core-rust
cargo test -p chunk-your-tools --all-features

# Python SDK (editable)
./scripts/local/dev/workflow.sh sdk-python
cd sdk/python && uv run pytest

# TypeScript SDK
./scripts/local/dev/workflow.sh sdk-typescript

# C + Go (builds FFI first)
./scripts/local/dev/workflow.sh sdk-go
./scripts/local/dev/workflow.sh sdk-c

# Example decompose/recompose against examples/input fixtures
./scripts/local/dev/workflow.sh indexer all
```

Legacy entry point `./scripts/local-dev.sh` delegates to `workflow.sh`.

## Version sync

Version source of truth: `Cargo.toml`

```bash
./scripts/publish/sync-version.sh          # read version from Cargo.toml
./scripts/publish/sync-version.sh 1.0.1    # set and propagate
```

## Publish (maintainers)

Tag `vX.Y.Z` triggers GitHub workflows:

1. `publish-crates.yml` → crates.io `chunk-your-tools`
2. `publish-pypi-sdk.yml`, `publish-npm-sdk.yml`, `publish-c-ffi.yml` (parallel)
3. `e2e-published-sdk.yml` after crates publish

```bash
./scripts/publish/publish-git.sh bump-patch
```

## FFI header sync

```bash
cargo build -p chunk-your-tools --no-default-features --features ffi
cp chunk_your_tools.h sdk/c/include/
```

Or: `bash sdk/c/scripts/build-c-lib.sh`
