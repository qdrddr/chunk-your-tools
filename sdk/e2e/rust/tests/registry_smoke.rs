#[path = "support/example_snapshot.rs"]
mod example_snapshot;

use chunk_your_tools::build_catalog_index;
use example_snapshot::{
    catalog_dict_from_snapshot, extract_snapshot_parts, load_snapshot, parse_test_args,
    resolve_snapshot_path, write_output,
};
use serde_json::json;

#[test]
fn build_catalog_index_from_registry_crate() {
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
    let index = build_catalog_index(&[tool], &[]);
    assert!(index
        .files
        .contains_key("schemas/decomposed/mcp__test__foo.json"));

    let meta = index.tool_schema_metadata();
    let decomposed = meta
        .get("decomposed")
        .and_then(|v| v.as_array())
        .expect("decomposed metadata array");
    let types: std::collections::HashMap<&str, &str> = decomposed
        .iter()
        .filter_map(|entry| {
            Some((
                entry.get("file_path")?.as_str()?,
                entry.get("type")?.as_str()?,
            ))
        })
        .collect();
    assert_eq!(
        types.get("schemas/decomposed/mcp__test__foo.json"),
        Some(&"tool")
    );
    assert_eq!(
        types.get("schemas/decomposed/mcp__test__foo/optional_field.json"),
        Some(&"property")
    );
}

#[test]
fn decompose_from_example_file() {
    let (example_file, output_file) = parse_test_args();
    let Some(example_file) = example_file else {
        eprintln!(
            "skipping decompose_from_example_file: set CHUNK_YOUR_TOOLS_E2E_FILE or pass --file after cargo test --"
        );
        return;
    };

    let snapshot_path = resolve_snapshot_path(&example_file);
    let data = load_snapshot(&snapshot_path);
    let _ = extract_snapshot_parts(&data);

    let catalog = catalog_dict_from_snapshot(&data);
    let json_chunks = catalog
        .get("json")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    let md_chunks = catalog
        .get("md")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    assert!(!json_chunks.is_empty(), "build_catalog_index produced no json chunks");
    assert!(!md_chunks.is_empty(), "build_catalog_index produced no md enum chunks");
    assert!(
        json_chunks.iter().any(|entry| {
            entry
                .get("file_path")
                .and_then(|v| v.as_str())
                .is_some_and(|path| {
                    path.contains("/schemas/decomposed/") && path.ends_with(".json")
                })
        }),
        "expected per-property decomposed json chunks"
    );

    write_output(&catalog, output_file.as_deref()).expect("write output");
}
