# chunk-your-tools C SDK

Pure C integration for the [chunk-your-tools](https://github.com/qdrddr/chunk-your-tools)
Rust crate at the repo root — tool schema decomposition and recomposition for MCP tool
definitions.

This package links the shared C library (`libchunk_your_tools` / `chunk_your_tools.dll`)
built from the crate's `ffi` feature.

## Prerequisites

- C11 compiler (GCC, Clang, or MSVC)
- CMake 3.16+ (recommended)
- Rust toolchain (`cargo`, `rustup`) — only when [building from source](#build-from-source)

## Prebuilt binaries (GitHub Release)

Precompiled `libchunk_your_tools` libraries for Linux, macOS, and Windows (x86_64 and ARM64)
are attached to each
[GitHub Release](https://github.com/qdrddr/chunk-your-tools/releases).

```bash
VERSION=v1.0.0
TRIPLET=aarch64-apple-darwin
curl -LO "https://github.com/qdrddr/chunk-your-tools/releases/download/${VERSION}/chunk-your-tools-ffi-${TRIPLET}.tar.gz"
mkdir -p cyt-ffi && tar -xzf "chunk-your-tools-ffi-${TRIPLET}.tar.gz" -C cyt-ffi
gcc -std=c11 -o myapp main.c -I cyt-ffi -L cyt-ffi -lchunk_your_tools
```

| Rust triplet | Archive |
| --- | --- |
| `x86_64-unknown-linux-gnu` | `chunk-your-tools-ffi-x86_64-unknown-linux-gnu.tar.gz` |
| `aarch64-unknown-linux-gnu` | `chunk-your-tools-ffi-aarch64-unknown-linux-gnu.tar.gz` |
| `x86_64-apple-darwin` | `chunk-your-tools-ffi-x86_64-apple-darwin.tar.gz` |
| `aarch64-apple-darwin` | `chunk-your-tools-ffi-aarch64-apple-darwin.tar.gz` |
| `x86_64-pc-windows-msvc` | `chunk-your-tools-ffi-x86_64-pc-windows-msvc.tar.gz` |
| `aarch64-pc-windows-msvc` | `chunk-your-tools-ffi-aarch64-pc-windows-msvc.tar.gz` |

Each archive contains the shared/static libraries, `chunk_your_tools.h`, and Windows import
libs when applicable. Verify with `SHA256SUMS` on the release page.

## Build from source

From the repository root:

```bash
./sdk/c/scripts/build-c-lib.sh
./sdk/c/scripts/build-c-lib.sh --target x86_64-unknown-linux-gnu
./sdk/c/scripts/build-c-lib.sh --all
```

The script copies the generated header to `sdk/c/include/chunk_your_tools.h`.

## CMake (recommended)

```bash
cmake -S sdk/c -B sdk/c/build -DCMAKE_BUILD_TYPE=Release \
  -DCYT_RUST_TARGET=$(rustc -vV | sed -n 's/^host: //p')
cmake --build sdk/c/build
ctest --test-dir sdk/c/build --output-on-failure
```

Consumer projects:

```cmake
find_package(CYT REQUIRED)
add_executable(myapp main.c)
target_link_libraries(myapp PRIVATE CYT::chunk_your_tools)
```

Or vendored:

```cmake
add_subdirectory(external/chunk-your-tools/sdk/c)
target_link_libraries(myapp PRIVATE CYT::chunk_your_tools)
```

## Manual link

```bash
TRIPLET=aarch64-apple-darwin
./sdk/c/scripts/build-c-lib.sh --target "$TRIPLET"
gcc -std=c11 -o myapp main.c \
  -I sdk/c/include \
  -L "target/$TRIPLET/release" \
  -lchunk_your_tools
```

## Header and memory rules

Include `chunk_your_tools.h`:

- Strings returned via `char**` out parameters **must** be freed with `cyt_free_string()`.
- Opaque handles (`CytCatalogBuilder`, `CytDecomposedCatalog`) **must** be freed with their
  matching `cyt_*_free()` function.
- Error messages are thread-local — call `cyt_get_last_error()` on the same thread that
  received a non-zero error code.

## Examples

| Example | Demonstrates |
| --- | --- |
| `examples/basic.c` | Catalog build |
| `examples/error_handling.c` | Failure paths, `cyt_get_last_error` |
| `examples/retrieve.c` | Decomposed catalog + `cyt_retrieve_tools` |
| `examples/policies.c` | Partition, merge, policy helpers |

## Related SDKs

- [Go SDK](../go/README.md) — cgo wrapper over the same C library
- [Python SDK](../python/README.md)
- [TypeScript SDK](../typescript/)

## Windows note

`build-c-lib.sh` is a bash script — use Git Bash, WSL, or MSYS2 on Windows. CMake examples
copy `chunk_your_tools.dll` beside test binaries automatically.
