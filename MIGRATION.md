# Migration from cyt-indexer / clear-your-tools

## Package renames

| Old | New |
| --- | --- |
| `cyt-indexer` (crates.io) | `chunk-your-tools` |
| `cyt-indexer-sdk` (PyPI/npm) | `chunk-your-tools-sdk` |
| `cyt_indexer` (Python import) | `chunk_your_tools` |
| `cyt-indexer` CLI | `chunk-your-tools` |
| `github.com/qdrddr/clear-your-tools/sdk/go` | `github.com/qdrddr/chunk-your-tools/sdk/go` |
| `libcyt_indexer` / `cyt_indexer.h` | `libchunk_your_tools` / `chunk_your_tools.h` |

## Removed APIs

The following modules were removed from the extracted library:

- BM25 search and cohesion chunking
- Skills / pageindex
- Cache materialization
- Pipeline (`prune_catalog_bm25_and_retrieve`, `coordinate_bm25_prune`, etc.)
- `documents` extraction helpers

## Survivors format

**New public format** (semantic names):

```json
{
  "tools": ["ToolId"],
  "properties": { "ToolId": ["optionalProp"] },
  "enums": ["enumValue"]
}
```

**Legacy format** (`{json, md}` with `file_path`) still works in `recompose` and
`retrieve_tools` for clear-your-tools integration.

## Rust symbol mapping

| cyt-indexer | chunk-your-tools |
| --- | --- |
| `build_catalog_from_tools` | same |
| `retrieve_tools_from_catalog` | same |
| `DecomposedCatalog` | same |
| `prune_catalog_bm25_and_retrieve` | removed — stay in clear-your-tools |
| `build_skills_index` | removed |

## clear-your-tools integration

After publishing `chunk-your-tools` to crates.io, update clear-your-tools `Cargo.toml`:

```toml
chunk-your-tools = "1"
```

Remove inlined decomposition code from clear-your-tools Rust core and import from the crate.
