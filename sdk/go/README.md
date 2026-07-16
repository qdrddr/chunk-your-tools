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

## Related SDKs

- [C SDK](../c/README.md)
- [Python SDK](../python/README.md)
- [TypeScript SDK](../typescript/README.md)
