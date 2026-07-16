# Chunk Your Tools — Configuration

**Chunk Your Tools** decomposes MCP tool definition JSON schemas into addressable chunks, then
recomposes pruned tool definitions from survivor lists.

---

## How it works

```text
tools.json
    │
    ▼
decompose  ──► catalog directory (per-tool JSON, optional-property chunks, enum MD, metadata)
    │
    ▼
survivors list (semantic names or legacy chunk paths)
    │
    ▼
recompose  ──► pruned tools.json
```

1. **Decompose** — parse each tool's `inputSchema` / `input_schema` into a catalog: tool roots
   keep required properties; optional properties split into separate chunks; enum values become
   Markdown chunks.
2. **Cache** — write `metadata.json` and per-chunk files under a catalog directory.
3. **Recompose** — merge surviving chunks back into valid tool definitions.

Scoring and survivor selection are the caller's responsibility. See
[clear-your-tools](https://github.com/qdrddr/clear-your-tools) for BM25, rerank, and LLM pruning
on top of this catalog format.

## CLI

Install:

```bash
cargo install chunk-your-tools
```

Or build locally: `cargo build -p chunk-your-tools --release`.

### `decompose`

```bash
chunk-your-tools decompose \
  --input path/to/tools.json \
  --output path/to/catalog
```

Input may be a top-level JSON array of tools or an object with a `tools` array.

### `recompose`

Provide exactly one source: `--input` (in-memory catalog) or `--catalog-dir` (on-disk catalog).

```bash
chunk-your-tools recompose \
  --catalog-dir path/to/catalog \
  --survivors path/to/survivors.json \
  --output path/to/pruned-tools.json
```

Policy and override flags (optional):

| Flag | Purpose |
| ---- | ------- |
| `--config` | JSON file with `pruning.tools.policy` (see below) |
| `--system-policy` | Default policy for non-`mcp__` tools |
| `--mcp-policy` | Default policy for `mcp__` tools |
| `--tool-type system\|mcp` | Treat every tool as system or MCP (overrides prefix detection) |
| `--per-tool` | JSON object of per-tool policy overrides |
| `--tool-policy TOOL=POLICY` | Repeatable per-tool override (`Agent=always_include`) |

Runnable examples: [`examples/decompose.sh`](examples/decompose.sh), [`examples/recompose.sh`](examples/recompose.sh).
See [examples/README.md](examples/README.md).

---

## Catalog layout

After `decompose`, a catalog directory typically contains:

```text
catalog/
  schemas/
    decomposed/
      Agent.json                    # tool root (required props only)
      Agent/model.json              # optional property chunk
      opus.md                       # enum value chunk
      metadata.json                 # chunk index
    full/
      Agent.json                    # full original schema per tool
      metadata.json
  metadata.json                     # catalog index (tools + file table)
```

Chunk paths under `schemas/decomposed/` are what legacy survivor lists reference. Semantic
recompose resolves tool/property/enum **names** to these paths automatically.

---

## Survivors format

### Semantic names (recommended)

```json
{
  "tools": ["mcp__github__create_issue", "Agent"],
  "properties": {
    "Agent": ["model"],
    "mcp__github__create_issue": ["body"]
  },
  "enums": ["opus", "haiku"]
}
```

| Field | Meaning |
| ----- | ------- |
| `tools` | Tool IDs/names to keep; omitted tools are dropped |
| `properties` | Per-tool optional property names to keep (required properties always survive; use dotted paths for nested optionals, e.g. `"config.timeout"`) |
| `enums` | Enum value names to keep |

### Legacy chunk lists

```json
{
  "json": ["schemas/decomposed/Agent.json", "schemas/decomposed/Agent/model.json"],
  "md": ["schemas/decomposed/opus.md"]
}
```

Legacy recompose applies pruning policies (below) when merging chunks.

---

## Pruning policies

Policies control how legacy chunk lists are merged during recompose.

### Defaults

| Category | Default | Detection |
| -------- | ------- | --------- |
| **System tools** | `prune_optional` | Names without `mcp__` prefix |
| **MCP tools** | `prune_all` | Names with `mcp__` prefix |

Override with CLI flags or a config file.

### Policy options

| Policy | Behavior |
| ------ | -------- |
| `always_include` | Full tool schema; no pruning |
| `prune_optional` | Tool always included; irrelevant optional properties dropped |
| `prune_all` | Entire tool may be removed if its root chunk is not in survivors |
| `prune_optional_descriptions` | Like `prune_optional`; pruned optionals return without descriptions |
| `prune_all_descriptions` | Like `prune_all`; when the root is pruned, only required properties are reinstated (descriptions stripped) |

### Config file shape

`--config` and library `policy_context_from_values` read:

```json
{
  "pruning": {
    "tools": {
      "policy": {
        "system_tool": "prune_optional",
        "mcp_tool": "prune_all",
        "per_tool": {
          "Agent": "prune_optional",
          "mcp__github__create_issue": "prune_all"
        }
      }
    }
  }
}
```

Only `pruning.tools.policy` is consumed. Top-level `pruning.policy` and `defaults.*` keys are
**not** read by this library.

Per-tool overrides from `--per-tool` and `--tool-policy` merge on top; later CLI `--tool-policy`
entries win for duplicate tool IDs.

---

## Runtime configuration (library / SDK)

Score thresholds and default policy strings can be set at runtime via `RuntimeConfig` (Rust) or
equivalent SDK helpers:

| Setting | Default | Used for |
| ------- | ------- | -------- |
| `decomposed_score` | `0.5` | Legacy retrieve scoring |
| `enum_score` | `0.2` | Enum chunk scoring |
| `rerank_score` | `0.003` | Optional-property survival threshold |
| `empty_optional_fallback_k` | `3` | Fallback optional chunks when a tool root would be empty |
| `default_system_policy` | `prune_optional` | `PolicyContext::new()` fallback |
| `default_mcp_policy` | `prune_all` | `PolicyContext::new()` fallback |

Rust example:

```rust
use chunk_your_tools::{RuntimeConfig, configure_runtime};

configure_runtime(RuntimeConfig {
    rerank_score: 0.01,
    ..Default::default()
});
```

---

## Input tool shapes

Tools may use Anthropic-style entries (`name`, `description`, `input_schema`) or MCP catalog
entries (`id`, `full_schema` with `inputSchema`). Both `input_schema` and `inputSchema` are
accepted when reading schemas.

---

## Development

See [DEV.md](DEV.md) for local workflow, version sync, and publish steps.

## Limitations

See [LIMITATIONS.md](LIMITATIONS.md) for scope boundaries, token accounting, and schema caveats.

## License

Apache-2.0 — see [LICENSE](LICENSE).
