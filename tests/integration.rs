use chunk_your_tools::{
    PolicyContext, ToolPolicy, build_catalog_from_tools, load_catalog_index_from_dir,
    policies::ToolKind, recompose_tools_from_index,
};
use serde_json::json;

#[test]
fn build_simple_tool() {
    let tool = json!({
        "id": "mcp__test__foo",
        "server": "test",
        "tool": "mcp__test__foo",
        "summary": "A test tool",
        "full_schema": {
            "id": "mcp__test__foo",
            "name": "mcp__test__foo",
            "description": "A test tool",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "required_field": {"type": "string"},
                    "optional_field": {"type": "string", "description": "opt"}
                },
                "required": ["required_field"]
            }
        }
    });
    let index = build_catalog_from_tools(&[tool]);
    assert!(
        index
            .files
            .contains_key("schemas/decomposed/mcp__test__foo.json")
    );
    assert!(index.files.keys().any(|k| k.contains("optional_field")));
}

#[test]
fn build_from_anthropic_tools() {
    let tool = json!({
        "name": "Agent",
        "description": "Launch agents",
        "input_schema": {
            "type": "object",
            "properties": {
                "prompt": {"type": "string"},
                "model": {"type": "string", "enum": ["opus", "haiku"]}
            },
            "required": ["prompt"]
        }
    });
    let index = build_catalog_from_tools(&[tool]);
    assert!(index.files.contains_key("schemas/decomposed/Agent.json"));
    assert!(index.files.keys().any(|k| k.contains("Agent/model")));
    assert!(index.files.contains_key("schemas/decomposed/haiku.md"));
}

#[test]
fn enum_md_files_without_json_quotes() {
    let index = chunk_your_tools::build_catalog_index(&[], &[json!("Bash"), json!("auto")]);
    assert_eq!(
        index
            .files
            .get("schemas/decomposed/Bash.md")
            .map(String::as_str),
        Some("Bash"),
    );
    assert_eq!(
        index
            .files
            .get("schemas/decomposed/auto.md")
            .map(String::as_str),
        Some("auto"),
    );
}

#[test]
fn recompose_from_catalog_dir_matches_in_memory() -> Result<(), String> {
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("examples/catalog");
    if !root.join("tools.json").is_file() {
        return Ok(());
    }
    let on_disk = load_catalog_index_from_dir(&root).map_err(|e| format!("load catalog: {e}"))?;
    let in_memory = build_catalog_from_tools(&on_disk.tools);
    let survivors = chunk_your_tools::NamedSurvivors {
        tools: vec!["Agent".into()],
        properties: std::collections::HashMap::new(),
        enums: vec![],
    };
    let ctx = PolicyContext::new();
    let from_disk = recompose_tools_from_index(&on_disk, &survivors, &ctx);
    let from_memory = recompose_tools_from_index(&in_memory, &survivors, &ctx);
    assert_eq!(from_disk.len(), from_memory.len());
    Ok(())
}

#[test]
fn tool_type_override_treats_agent_as_mcp() -> Result<(), String> {
    let tool = json!({
        "name": "Agent",
        "input_schema": {
            "type": "object",
            "properties": {
                "prompt": {"type": "string"},
                "model": {"type": "string", "enum": ["opus", "haiku"]}
            },
            "required": ["prompt"]
        }
    });
    let index = build_catalog_from_tools(&[tool]);
    let survivors = chunk_your_tools::NamedSurvivors {
        tools: vec!["Agent".into()],
        properties: std::collections::HashMap::new(),
        enums: vec![],
    };
    let mut ctx = PolicyContext::new();
    ctx.mcp_policy = ToolPolicy::PruneAll;
    ctx.system_policy = ToolPolicy::AlwaysInclude;
    ctx.tool_kind_override = Some(ToolKind::Mcp);
    let result = recompose_tools_from_index(&index, &survivors, &ctx);
    assert_eq!(result.len(), 1);
    let schema = result[0]
        .get("input_schema")
        .or_else(|| result[0].get("inputSchema"))
        .and_then(|v| v.get("properties"))
        .and_then(|v| v.as_object())
        .ok_or_else(|| "missing properties".to_string())?;
    assert!(!schema.contains_key("model"));
    Ok(())
}
