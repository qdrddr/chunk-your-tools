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

## What it does

1. **Decompose** — parse MCP tool definition JSON into addressable chunks (tools, optional properties, enums).
2. **Cache** — write `metadata.json` and per-chunk files under a catalog directory.
3. **Recompose** — rebuild pruned tool definitions from survivor lists.

## Packages

<details open>
<summary><strong>Published packages</strong></summary>

<table border="0">
  <tr>
    <td valign="top">

**`chunk-your-tools`** ([crates.io][rust-link])
    </td>
    <td valign="top">

Rust library and CLI
    </td>
    <td valign="top">

[![crates.io chunk-your-tools][rust-version-shield]][rust-link]

[![crates.io downloads][rust-downloads-shield]][rust-link]
    </td>
  </tr>
  <tr>
    <td valign="top">

**`chunk-your-tools`** ([PyPI][pypi-link])
    </td>
    <td valign="top">

Python SDK (`import chunk_your_tools`)
    </td>
    <td valign="top">

[![PyPI chunk-your-tools][pypi-version-shield]][pypi-link]

[![PyPI downloads][pypi-downloads-shield]][pypi-link]
    </td>
  </tr>
  <tr>
    <td valign="top">

**`chunk-your-tools`** ([npm][npm-link])
    </td>
    <td valign="top">

TypeScript SDK
    </td>
    <td valign="top">

[![npm chunk-your-tools][npm-version-shield]][npm-link]

[![npm downloads][npm-downloads-shield]][npm-link]
    </td>
  </tr>
  <tr>
    <td valign="top">

**`libchunk_your_tools`** ([Release][c-link])
    </td>
    <td valign="top">

C library via CMake / `build-c-lib.sh`
    </td>
    <td valign="top">

[![GitHub sdk/c][c-version-shield]][c-link]
    </td>
  </tr>
  <tr>
    <td valign="top">

**`sdk/go`** ([pkg.go.dev][go-link])
    </td>
    <td valign="top">

Go SDK via cgo (`import chunkyourtools`)
    </td>
    <td valign="top">

[![pkg.go.dev sdk/go][go-version-shield]][go-link]
    </td>
  </tr>
</table>

</details>

## Quick start

Install the CLI:

```bash
cargo install chunk-your-tools
```

Or build locally: `cargo build -p chunk-your-tools --release`.

Library installs:

```bash
cargo add chunk-your-tools
pip install chunk-your-tools
npm install chunk-your-tools
```

Try the bundled walkthrough — decompose a sample tool catalog, then recompose pruned variants:

```bash
./examples/decompose.sh
export PATH="$PWD/target/release:$PATH"
./examples/recompose.sh
```

See [examples/README.md](examples/README.md) for survivor formats, output paths, and CLI flags.

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

Survivor lists tool names, optional properties, and enum values to keep.

## SDKs

| SDK | Path | Docs |
| --- | --- | --- |
| Python | `sdk/python` | [README](sdk/python/README.md) |
| TypeScript | `sdk/typescript` | [README](sdk/typescript/README.md) |
| Go | `sdk/go` | [README](sdk/go/README.md) |
| C | `sdk/c` | [README](sdk/c/README.md) |

Go SDK smoke test: [examples/go-git-smoke/README.md](examples/go-git-smoke/README.md).

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

Apache-2.0 — see [LICENSE](LICENSE).

[license-badge-shield]: https://img.shields.io/badge/License-Apache_2.0-yellow?style=for-the-badge
[license-link]: LICENSE
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
[c-version-shield]: https://img.shields.io/github/v/release/qdrddr/chunk-your-tools?style=flat-square&label=sdk%2Fc&color=555&logoColor=white
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
