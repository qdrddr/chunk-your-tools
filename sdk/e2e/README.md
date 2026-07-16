# Registry end-to-end tests

Smoke tests that install **only published packages** from public registries—or, for Go/C, a **sparse GitHub tag
checkout**—not the active monorepo tree (unless `--workspace` is set).

| Harness | Source | Package |
| ------- | ------ | ------- |
| [`rust/`](rust/) | [crates.io](https://crates.io/crates/chunk-your-tools) | `chunk-your-tools` |
| [`python/`](python/) | [PyPI](https://pypi.org/project/chunk-your-tools/) | `chunk-your-tools` |
| [`typescript/`](typescript/) | [npm](https://www.npmjs.com/package/chunk-your-tools) | `chunk-your-tools` |
| [`go/`](go/) | [GitHub tag](https://github.com/qdrddr/chunk-your-tools/tags) | `github.com/qdrddr/chunk-your-tools/sdk/go` |
| [`c/`](c/) | [GitHub tag](https://github.com/qdrddr/chunk-your-tools/tags) | `sdk/c` + `libchunk_your_tools` built from tagged crate |

## CI

Registry E2E workflows (each runs after its publish workflow succeeds via `workflow_run`):

| Workflow | Trigger | Harness |
| -------- | ------- | ------- |
| `2. E2E published (crates.io)` | `1. Publish chunk-your-tools to crates.io` | `rust/` |
| `4. E2E published (PyPI)` | `3. Publish chunk-your-tools to PyPI` | `python/` |
| `4. E2E published (npm)` | `3. Publish chunk-your-tools to npm` | `typescript/` |
| `2. E2E published packages` | `1. Publish chunk-your-tools to crates.io` | `go/`, `c/` |

Each workflow reads semver from the parent publish artifact
(`chunk-your-tools-release-version`), polls the relevant registry or GitHub tag until that version is
available, then runs the harness tests.

Complements:

- [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) — source-tree tests on PR/push
- [`.github/workflows/sdk-c-go.yml`](../../.github/workflows/sdk-c-go.yml) — monorepo C/Go matrix on PR/push
- Publish chain — push tag `vX.Y.Z` → `1. Publish chunk-your-tools to crates.io` → (`3. Publish PyPI`, `3. Publish npm`,
  `2. E2E published (crates.io)`, `2. E2E published packages`; then `4. E2E published (PyPI/npm)` after each publish)

## Local run

Use [`scripts/run-local.sh`](scripts/run-local.sh) after a release is on registries (and tagged on GitHub for Go/C).
It renders manifests, optionally polls registries/tags, and runs the harness tests.

```bash
# Workspace version from Cargo.toml, all five targets
./sdk/e2e/scripts/run-local.sh

# Explicit version (packages must already be published; tag must exist for go/c)
./sdk/e2e/scripts/run-local.sh 0.1.10

# One target, skip registry polling when you know the version is live
./sdk/e2e/scripts/run-local.sh --skip-wait python
./sdk/e2e/scripts/run-local.sh v0.1.10 rust typescript

# Go/C against current monorepo (unreleased local work)
./sdk/e2e/scripts/run-local.sh --workspace --skip-wait go c
```

Targets: `rust`, `python`, `typescript`, `go`, `c`, `all` (default).

**Prerequisites:** `cargo`, `go` 1.25+ with CGO, `cmake`, `uv` (Python 3.13+), `node`/`npm`, network access to public
registries and GitHub.

### CI-style run

For parity with the GitHub workflow (e.g. in automation), set the version explicitly and use
[`scripts/run-all.sh`](scripts/run-all.sh):

```bash
export CHUNK_YOUR_TOOLS_RELEASE_VERSION=0.1.10   # or TAG=v0.1.10
./sdk/e2e/scripts/run-all.sh
```

Low-level registry polling: [`scripts/wait-registry.sh`](scripts/wait-registry.sh) targets `crate`, `pypi-sdk`,
`npm`, `tag`. Set `SKIP_REGISTRY_WAIT=1` to skip waits in `run-local.sh`, `run-all.sh`, or `run-target.sh`.

## Go/C staging

Go and C harnesses clone tag `vX.Y.Z` into a temp directory (`CHUNK_YOUR_TOOLS_E2E_STAGING`), build
`libchunk_your_tools` from the tagged Rust crate at the repo root, then run isolated tests:

- Go: rendered `go.mod` uses a `replace` directive to the staging `sdk/go` tree (cgo links `../../target/...` from there).
- C: CMake links the staging shared library and header under `sdk/c/include/`.

Scripts: [`prepare-release-checkout.sh`](scripts/prepare-release-checkout.sh), [`build-staging-c-lib.sh`](scripts/build-staging-c-lib.sh).

## Manifest templates

Version pins live in `*.in` templates (`@CHUNK_YOUR_TOOLS_RELEASE_VERSION@` placeholder; Go also uses `@CHUNK_YOUR_TOOLS_E2E_STAGING@`).
`render-manifests.sh` writes gitignored `Cargo.toml`, `pyproject.toml`, `package.json`, and `go.mod` files so PRs do
not churn lockfiles when only the release version changes.

| Script | Role |
| ------ | ---- |
| [`scripts/render-manifests.sh`](scripts/render-manifests.sh) | Expand `*.in` templates |
| [`scripts/run-all.sh`](scripts/run-all.sh) | Run all harnesses (CI-style) |
| [`scripts/run-local.sh`](scripts/run-local.sh) | Local entry with defaults and flags |
| [`scripts/run-target.sh`](scripts/run-target.sh) | Run one harness (`rust`, `python`, `typescript`, `go`, `c`) |
| [`scripts/wait-registry.sh`](scripts/wait-registry.sh) | Poll crates.io / PyPI / npm / GitHub tag |
| [`scripts/build-staging-c-lib.sh`](scripts/build-staging-c-lib.sh) | Build `libchunk_your_tools` inside staging checkout |
