# Chunk Your Tools

Decompose and recompose MCP tool definition JSON schemas. Split large tool `inputSchema`
trees into addressable chunks (tools, optional properties, enums), then rebuild pruned tool
definitions from survivor lists.

This library is extracted from [clear-your-tools](https://github.com/qdrddr/clear-your-tools)
and contains **only** decomposition/recomposition — no BM25, proxy, or agent integration.

## Install

| Channel | Package | Import |
| --- | --- | --- |
| Rust crate | `chunk-your-tools` | `chunk_your_tools` |
| PyPI | `chunk-your-tools-sdk` | `chunk_your_tools` |
| npm | `chunk-your-tools-sdk` | `chunk-your-tools-sdk` |
| Go | `github.com/qdrddr/chunk-your-tools/sdk/go` | `chunkyourtools` |
| C | `libchunk_your_tools` | `chunk_your_tools.h` |

```bash
cargo add chunk-your-tools
pip install chunk-your-tools-sdk
npm install chunk-your-tools-sdk
```

CLI:

```bash
cargo install chunk-your-tools
```

## CLI

### Decompose

```bash
chunk-your-tools decompose --input tools.json --output ./catalog
```

Writes decomposed JSON/Markdown chunks under `./catalog/schemas/decomposed/`.

### Recompose (in-memory)

```bash
chunk-your-tools recompose \
  --input tools.json \
  --survivors survivors.json \
  --output recomposed-tools.json
```

No catalog directory is required — decomposition runs in memory.

### Survivors format (semantic names)

```json
{
  "tools": ["mcp__github__create_issue", "Agent"],
  "properties": {
    "Agent": ["model", "optional_field"],
    "mcp__github__create_issue": ["title"]
  },
  "enums": ["opus", "haiku", "Bash"]
}
```

- `tools`: tool IDs/names to keep (omitted tools are dropped)
- `properties`: per-tool optional property names (required properties always survive;
  use dotted paths for nested optionals, e.g. `"config.timeout"`)
- `enums`: enum value names to keep

Legacy `{json, md}` chunk lists (with `file_path`) are also accepted for integration with
clear-your-tools pruners.

## Library (Rust)

```rust
use chunk_your_tools::{
    NamedSurvivors, PolicyContext, build_catalog_from_tools, recompose_tools_from_names,
};
use serde_json::json;

let tools = vec![/* MCP tool definitions */];
let survivors = NamedSurvivors::from_value(&json!({
    "tools": ["Agent"],
    "properties": { "Agent": ["model"] },
    "enums": ["opus"]
})).unwrap();
let ctx = PolicyContext::new();
let recomposed = recompose_tools_from_names(&tools, &survivors, &ctx);
```

## SDKs

| SDK | Path | Docs |
| --- | --- | --- |
| Python | `sdk/python` | [README](sdk/python/README.md) |
| TypeScript | `sdk/typescript` | [README](sdk/typescript/README.md) |
| Go | `sdk/go` | [README](sdk/go/README.md) |
| C | `sdk/c` | [README](sdk/c/README.md) |

## Development

See [DEV.md](DEV.md) and run `./scripts/local-dev.sh all` for the full monorepo check.

## License

Apache-2.0
