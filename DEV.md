# Development guide

## Repository layout

```text
./   # Rust core + CLI
sdk/python/                  # PyPI chunk-your-tools
sdk/typescript/              # npm chunk-your-tools
sdk/go/                      # Go module
sdk/c/                       # C FFI + CMake
sdk/e2e/                     # Published-package smoke tests
scripts/                     # local-dev, sync-version, publish helpers
```

## Local workflow

```bash
# Full check
./scripts/local-dev.sh all

# Rust only
./scripts/local-dev.sh core-rust
cargo test -p chunk-your-tools --all-features

# Python SDK (editable)
./scripts/local-dev.sh sdk-python
cd sdk/python && uv run pytest

# TypeScript SDK
./scripts/local-dev.sh sdk-typescript

# C + Go (builds FFI first)
./scripts/local-dev.sh sdk-go
./scripts/local-dev.sh sdk-c

# Example decompose/recompose against debug/full_example.json
./scripts/local-dev.sh indexer all
```

## Version sync

Version source of truth: `Cargo.toml`

```bash
./scripts/sync-version.sh          # read version from Cargo.toml
./scripts/sync-version.sh 1.0.1      # set and propagate
```

## Publish (maintainers)

Tag `vX.Y.Z` triggers GitHub workflows:

1. `publish-crates.yml` → crates.io `chunk-your-tools`
2. `publish-pypi-sdk.yml`, `publish-npm-sdk.yml`, `publish-c-ffi.yml` (parallel)
3. `e2e-published-sdk.yml` after crates publish

Manual helper: `./scripts/publish.sh`

## FFI header sync

```bash
cargo build -p chunk-your-tools --no-default-features --features ffi
cp chunk_your_tools.h sdk/c/include/
```

Or: `bash sdk/c/scripts/build-c-lib.sh`
