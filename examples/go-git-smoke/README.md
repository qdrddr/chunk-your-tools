# Go SDK git smoke test

`go-git-smoke/` is a end-to-end check for the **Go SDK**: a minimal app that consumes
`github.com/qdrddr/chunk-your-tools/sdk/go` from a git tag checkout and verifies that:

| Concern | Where to look |
| --- | --- |
| Decompose/recompose MCP tool schemas (CLI) | [`../decompose.sh`](../decompose.sh), [`../recompose.sh`](../recompose.sh), [`../README.md`](../README.md) |
| Go SDK + C FFI from a git tag (this folder) | `prepare.sh`, `ensure-ffi.sh`, `run.sh` below |

It checks that:

1. A sparse clone of the release tag provides the Go SDK sources and root Rust crate
2. C FFI artifacts can be fetched from the matching GitHub Release
3. The binary links and runs with CGO outside the monorepo

## Run

From the monorepo:

```bash
cd examples/go-git-smoke
chmod +x prepare.sh ensure-ffi.sh run.sh
./run.sh
```

Or copy this folder anywhere and run the same commands:

```bash
cd go-git-smoke
chmod +x prepare.sh ensure-ffi.sh run.sh
./run.sh
```

## How it works

1. `prepare.sh` sparse-clones `v1.0.0` into `.staging/1.0.0/` (`. sdk/c sdk/go`)
2. Renders `go.mod` from `go.mod.in` with `replace => .staging/.../sdk/go`
3. `ensure-ffi.sh` delegates to `sdk/go/cmd/chunk-native-ensure`, which downloads
   `chunk-your-tools-ffi-<triplet>.tar.gz` from GitHub Releases
4. `run.sh` links the static archive via `chunk-native-ensure --print-env` and runs a tiny
   API call

Release `.dylib` / `.so` files embed CI rpaths; `chunk-native-ensure -static-only` installs
only `libchunk_your_tools.a` (or `.lib` on Windows) to avoid runtime load failures on macOS.

## Manual steps

```bash
export CGO_ENABLED=1
export CYT_RELEASE_VERSION=1.0.0

./prepare.sh
STAGING="$(./prepare.sh)"
./ensure-ffi.sh "$STAGING" "$CYT_RELEASE_VERSION"
eval "$(./ensure-ffi.sh --print-cgo "$STAGING")"

go mod tidy
go build -o chunk-go-git-smoke .
./chunk-go-git-smoke
```

## Prerequisites

- Go 1.25+ with CGO enabled
- git, curl, and network access for clone + GitHub Release download
- C toolchain (clang/gcc; Xcode CLT on macOS)

## Expected output

```text
chunk-your-tools Go git smoke OK
  sdk module version: 1.0.0
  native lib version: 1.0.0
  empty catalog index bytes: 40
  cwd: /path/to/your/copy
```

## CLI examples (elsewhere)

Decompose/recompose walkthroughs live in the parent `examples/` directory, not here:

```bash
# from repo root
./examples/decompose.sh
./examples/recompose.sh
```

See [`../README.md`](../README.md) for survivor formats, fixtures, and output files.

