# chunk-your-tools

Rust library for [chunk-your-tools](https://crates.io/crates/chunk-your-tools) — MCP tool schema decomposition and recomposition.

## Add dependency

```toml
[dependencies]
chunk-your-tools = "1"
serde_json = "1"
```

## Usage

```rust
use chunk_your_tools::{
    build_catalog_from_tools, recompose_tools_from_names, NamedSurvivors, PolicyContext,
};

let index = build_catalog_from_tools(&tools);
let pruned = recompose_tools_from_names(
    &tools,
    &NamedSurvivors {
        tools: vec!["Agent".into()],
        properties: [("Agent".into(), vec!["model".into()])].into(),
        enums: vec!["opus".into()],
    },
    &PolicyContext::new(),
);
```
