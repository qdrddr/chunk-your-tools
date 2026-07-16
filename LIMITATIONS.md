# Limitations

This document describes what **chunk-your-tools** does and does not handle. For configuration
and CLI flags, see [CONFIG.md](CONFIG.md).

## Scope

**chunk-your-tools** is a library for MCP tool schema **decomposition** and **recomposition** only.

It does **not** provide:

- A reverse proxy or request interceptor
- BM25, rerank, or LLM pruning pipelines
- Agent or IDE integration (Claude Code, Cursor, Codex, etc.)
- Automatic survivor selection from a user query

## Survivor lists

Recompose requires an explicit survivor list. The library does not infer which tools, optional
properties, or enum values are relevant to a task.

- **Semantic format** — you supply tool IDs, property names, and enum names.

If survivors omit a tool root, that tool is dropped (subject to the active pruning policy).

## Required properties

Decomposition always keeps **required** properties on tool root chunks. Recomposition never
removes required fields from tools that survive. Only **optional** properties are split into
separate chunks and can be pruned independently.

## Tool classification

System vs MCP classification defaults to the `mcp__` name prefix:

- `mcp__…` → MCP tool (`prune_all` by default)
- Everything else → system tool (`prune_optional` by default)

Use `--tool-type` or `PolicyContext.tool_kind_override` when your catalog does not follow this
naming convention.

## Token counts

Token counts in catalog metadata are placeholders only (`token_count: null`). This library does
not compute tokenizer-accurate sizes. Any savings estimates must come from the host application
or provider billing data.

## Schema coverage

Decomposition targets MCP-style tool definitions with JSON Schema `inputSchema` /
`input_schema` objects:

- Optional top-level properties are chunked; nested optionals use dotted survivor paths
  (e.g. `"config.timeout"`).
- Enum values are extracted into separate Markdown chunks when declared on properties.
- Both `input_schema` (Anthropic) and `inputSchema` (MCP) field names are accepted.

Arbitrary JSON Schema constructs (e.g. `oneOf` / `allOf` at the root, deeply dynamic schemas)
may not decompose into clean optional-property chunks. Validate output for unusual schemas.

## Description policies

`prune_optional_descriptions` and `prune_all_descriptions` affect **legacy** recompose paths
that merge scored chunk lists. They reinstate pruned optional properties without `description`
fields (names, types, and enum hints remain). Semantic name-based recompose uses survivor lists
directly and does not apply description stripping unless you use the legacy retrieve pipeline
with policies.

## Empty optional mitigation

When aggressive pruning would leave a tool root with no `properties`, the library can append
up to `empty_optional_fallback_k` (default **3**) highest-scoring optional chunks from a scored
catalog, or drop the tool under LLM-style policies. This behavior applies to legacy retrieve /
policy-aware recompose, not to bare semantic survivor lists.

## Host integration

chunk-your-tools alone is suitable for:

- Offline catalog generation and inspection
- Custom pruning pipelines that produce survivor JSON
- Embedding decomposition/recompose in another service or SDK
