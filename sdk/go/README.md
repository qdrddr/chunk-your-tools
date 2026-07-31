# chunk-your-tools Go SDK

Go bindings for [chunk-your-tools](https://github.com/qdrddr/chunk-your-tools) via **cgo**,
wrapping the same C library and header as [sdk/c](../c/).

```text
GitHub Release / build-c-lib.sh  →  libchunk_your_tools + chunk_your_tools.h
         ↓
sdk/go (cgo)  →  chunkyourtools package
```

## Install

```bash
go get github.com/qdrddr/chunk-your-tools/sdk/go/v2
```

```go
import chunkyourtools "github.com/qdrddr/chunk-your-tools/sdk/go/v2"
```

## Native library bootstrap

Before `go build` / `go test`, ensure C FFI artifacts are present:

```bash
go tool chunk-native-ensure    # downloads prebuilt C FFI for your platform (once per version)
```

Or build from the monorepo root:

```bash
./sdk/c/scripts/build-c-lib.sh
cd sdk/go && go run ./cmd/chunk-native-ensure -static-only
```

Print cgo flags for manual builds:

```bash
eval "$(go tool chunk-native-ensure --print-env)"
```

`chunk-native-ensure`:

1. Reuses `target/<triplet>/release` when `./sdk/c/scripts/build-c-lib.sh` was run
2. Otherwise downloads `chunk-your-tools-ffi-<triplet>.tar.gz` from GitHub Release
   matching the SDK version
3. Installs into `$XDG_CACHE_HOME/chunk-your-tools/<version>/<triplet>/` and copies into
   `sdk/go/native/<triplet>/` when writable

## Prebuilt FFI archives

Attached to each [GitHub Release](https://github.com/qdrddr/chunk-your-tools/releases):

| Rust triplet | Archive |
| --- | --- |
| `x86_64-unknown-linux-gnu` | `chunk-your-tools-ffi-x86_64-unknown-linux-gnu.tar.gz` |
| `aarch64-unknown-linux-gnu` | `chunk-your-tools-ffi-aarch64-unknown-linux-gnu.tar.gz` |
| `x86_64-apple-darwin` | `chunk-your-tools-ffi-x86_64-apple-darwin.tar.gz` |
| `aarch64-apple-darwin` | `chunk-your-tools-ffi-aarch64-apple-darwin.tar.gz` |
| `x86_64-pc-windows-msvc` | `chunk-your-tools-ffi-x86_64-pc-windows-msvc.tar.gz` |
| `aarch64-pc-windows-msvc` | `chunk-your-tools-ffi-aarch64-pc-windows-msvc.tar.gz` |

## API overview

The Go package mirrors the C FFI surface:

- `BuildCatalogIndex`, `RetrieveTools`
- Policy helpers (`PartitionCatalog`, `MergeCatalog`, pass-through checks)
- Survivor resolution via semantic names or legacy chunk lists

See package docs and [sdk/c/README.md](../c/README.md) for memory ownership rules.

## Tests

```bash
cd sdk/go
go test ./...
```

## Dev tools (pre-commit / CI)

All Go formatters and linters run through
[scripts/pre-commit-hooks/go-sdk-precommit.sh](../../scripts/pre-commit-hooks/go-sdk-precommit.sh)
(pinned `go run ...@version`, not in `go.mod`).

| pre-commit hook | Script command |
| --- | --- |
| `go-fumpt` | `fumpt` |
| `go-imports` | `imports` |
| `go-mod-tidy-repo` | `tidy` |
| `go-staticcheck-repo-mod` | `staticcheck` |
| `go-critic` | `critic` |
| `go-sec-repo-mod` | `sec` |
| `go-build-repo-mod` | `build` |
| `go-test-repo-mod` | `test` |

`prek-loop.sh -g go` runs the same hooks (see
[prek-hook-groups.yaml](../../scripts/pre-commit-hooks/prek-hook-groups.yaml)).

Aggregates for local dev / one-shot checks:

```bash
bash scripts/pre-commit-hooks/go-sdk-precommit.sh fmt    # gofumpt + goimports
bash scripts/pre-commit-hooks/go-sdk-precommit.sh lint   # staticcheck + gocritic
bash scripts/pre-commit-hooks/go-sdk-precommit.sh check  # tidy + fmt + lint + sec
```

Override tool versions with `GOFUMPT_VERSION`, `GOIMPORTS_VERSION`, `STATICCHECK_VERSION`,
`GOCRITIC_VERSION`, `GOSEC_VERSION`.

**gosec in CI:** when `CI` is set, the `sec` command runs
`go install github.com/securego/gosec/v2/cmd/gosec@<version>`. Or install explicitly:

```bash
./scripts/deps/ensure-go-gosec.sh
bash scripts/pre-commit-hooks/go-sdk-precommit.sh sec
```

Locally (no `CI`), gosec uses `go run ...@version`.

## Version bump

SDK semver is propagated by [scripts/publish/sync-version.sh](../../scripts/publish/sync-version.sh)
(Cargo.toml → Python, npm, C CMake, `sdk/go/moduleversion/version.go`). Release with
[scripts/publish/publish-git.sh](../../scripts/publish/publish-git.sh) (`bump-patch`, `bump-minor`, or `vX.Y.Z`).

Pre-commit runs `sync-version` when manifests drift. `go test` includes
[versionsync_test.go](versionsync_test.go) to catch Go/Cargo version mismatch.

## Related SDKs

- [C SDK](../c/README.md)
- [Python SDK](../python/README.md)
- [TypeScript SDK](../typescript/README.md)
