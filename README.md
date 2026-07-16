# Chunk Your Tools

<div align="center">

[![License][license-badge-shield]][license-link]
[![version][version-shield]][release-link]

![Rust][rust-tech-shield]
![Python][python-tech-shield]
![TypeScript][typescript-shield]
![Go][go-tech-shield]
![C][c-tech-shield]

</div>

Decompose and recompose MCP tool definition JSON schemas. Split large tool `inputSchema`
trees into addressable chunks (tools, optional properties, enums), then rebuild pruned tool
definitions from survivor lists.

This library is extracted from [clear-your-tools](https://github.com/qdrddr/clear-your-tools)
and contains **only** decomposition/recomposition — no BM25, proxy, or agent integration.

## Install

| Channel | Package | Import | Status |
| --- | --- | --- | --- |
| Rust crate | `chunk-your-tools` ([crates.io](https://crates.io/crates/chunk-your-tools)) | `chunk_your_tools` | [![crates.io chunk-your-tools][rust-version-shield]][rust-link] <br> [![crates.io downloads][rust-downloads-shield]][rust-link] |
| PyPI | `chunk-your-tools` ([PyPI](https://pypi.org/project/chunk-your-tools/)) | `chunk_your_tools` | [![PyPI chunk-your-tools][pypi-version-shield]][pypi-link] <br> [![PyPI downloads][pypi-downloads-shield]][pypi-link] |
| npm | `chunk-your-tools` ([npm](https://www.npmjs.com/package/chunk-your-tools)) | `chunk-your-tools` | [![npm chunk-your-tools][npm-version-shield]][npm-link] <br> [![npm downloads][npm-downloads-shield]][npm-link] |
| Go | [`sdk/go`](https://pkg.go.dev/github.com/qdrddr/chunk-your-tools/sdk/go) | `chunkyourtools` | [![pkg.go.dev sdk/go][go-version-shield]][go-link] |
| C | [`libchunk_your_tools`](https://github.com/qdrddr/chunk-your-tools/releases) | `chunk_your_tools.h` | [![GitHub libchunk_your_tools][c-version-shield]][c-link] |

```bash
cargo add chunk-your-tools
pip install chunk-your-tools
npm install chunk-your-tools
```

CLI:

```bash
cargo install chunk-your-tools
```

## CLI

```bash
# Decompose tools.json into a searchable catalog
chunk-your-tools decompose --input tools.json --output ./catalog

# Recompose pruned tools from survivor lists (catalog optional)
chunk-your-tools recompose \
  --input tools.json \
  --survivors survivors.json \
  --output recomposed-tools.json
```

Survivor lists name tools, optional properties, and enum values to keep. See
[examples/README.md](examples/README.md) for the full format, runnable scripts, and sample
output.

## Examples

```bash
./examples/decompose.sh
./examples/recompose.sh
```

Covers catalog-based and in-memory workflows, legacy survivor formats, and pruning policies.
Go SDK smoke test: [examples/go-git-smoke/README.md](examples/go-git-smoke/README.md).

## SDKs

| SDK | Path | Docs |
| --- | --- | --- |
| Python | `sdk/python` | [README](sdk/python/README.md) |
| TypeScript | `sdk/typescript` | [README](sdk/typescript/README.md) |
| Go | `sdk/go` | [README](sdk/go/README.md) |
| C | `sdk/c` | [README](sdk/c/README.md) |

## Supported platforms

<div align="center">

[![Windows][windows-shield]](#supported-platforms)
[![macOS][macos-shield]](#supported-platforms)
[![Linux][linux-shield]](#supported-platforms)

</div>

The Rust crate, Python/npm SDKs, and `libchunk_your_tools` FFI support **Windows**, **macOS**, and **Linux**.

## Development

See [DEV.md](DEV.md) and run `./scripts/local-dev.sh all` for the full monorepo check.

## License

Apache-2.0

[license-badge-shield]: https://img.shields.io/badge/License-Apache_2.0-yellow?style=for-the-badge
[license-link]: https://github.com/qdrddr/chunk-your-tools/blob/main/LICENSE
[version-shield]: https://img.shields.io/github/v/release/qdrddr/chunk-your-tools?style=flat-square&label=version&color=4385BE&logoColor=white
[release-link]: https://github.com/qdrddr/chunk-your-tools/releases
[rust-version-shield]: https://img.shields.io/crates/v/chunk-your-tools?logo=rust&color=e6522c&logoColor=white
[rust-downloads-shield]: https://img.shields.io/crates/d/chunk-your-tools?logo=rust&color=e6522c&logoColor=white
[rust-link]: https://crates.io/crates/chunk-your-tools
[pypi-version-shield]: https://img.shields.io/pypi/v/chunk-your-tools?logo=pypi&logoColor=white&color=2E8B57
[pypi-downloads-shield]: https://img.shields.io/pypi/dm/chunk-your-tools?logo=pypi&logoColor=white&color=2E8B57
[pypi-link]: https://pypi.org/project/chunk-your-tools/
[npm-version-shield]: https://img.shields.io/npm/v/chunk-your-tools?logo=npm&color=3178C6&logoColor=white
[npm-downloads-shield]: https://img.shields.io/npm/dm/chunk-your-tools?logo=npm&color=3178C6&logoColor=white
[npm-link]: https://www.npmjs.com/package/chunk-your-tools
[c-version-shield]: https://img.shields.io/github/v/release/qdrddr/chunk-your-tools?style=flat-square&label=libchunk_your_tools&color=555&logoColor=white
[c-link]: https://github.com/qdrddr/chunk-your-tools/releases
[go-version-shield]: https://pkg.go.dev/badge/github.com/qdrddr/chunk-your-tools/sdk/go
[go-link]: https://pkg.go.dev/github.com/qdrddr/chunk-your-tools/sdk/go
[rust-tech-shield]: https://img.shields.io/badge/-Rust-e6522c?logo=rust&logoColor=white
[python-tech-shield]: https://img.shields.io/badge/-Python-3776AB?logo=python&logoColor=white
[typescript-shield]: https://img.shields.io/badge/-TypeScript-3178C6?logo=typescript&logoColor=white
[go-tech-shield]: https://img.shields.io/badge/-Go-00ADD8?logo=go&logoColor=white
[c-tech-shield]: https://img.shields.io/badge/-C-A8B9CC?logo=c&logoColor=white
[windows-shield]: https://img.shields.io/badge/Windows-supported-0078D6?logo=windows&logoColor=white
[macos-shield]: https://img.shields.io/badge/macOS-supported-000000?logo=apple&logoColor=white
[linux-shield]: https://img.shields.io/badge/Linux-supported-FCC624?logo=linux&logoColor=black
