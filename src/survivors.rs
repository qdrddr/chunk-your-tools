//! Map semantic survivor names (tools, properties, enums) to internal catalog survivor data.

use crate::build::CatalogIndex;
use crate::paths::{self, decomposed_prefix, json_ext, md_ext};
use crate::policies::PolicyContext;
use crate::retrieve::{
    DecomposedCatalog, RetrieveOptions, build_process_groups_options, retrieve_tools_from_catalog,
};
use crate::tool_entries::build_catalog_from_tools;
use serde_json::{Value, json};
use std::collections::{HashMap, HashSet};

/// Semantic survivor selection: tool IDs, per-tool optional property names, enum value names.
#[derive(Debug, Clone, Default)]
pub struct NamedSurvivors {
    pub tools: Vec<String>,
    pub properties: HashMap<String, Vec<String>>,
    pub enums: Vec<String>,
}

impl NamedSurvivors {
    /// Parse from a survivors JSON object.
    ///
    /// # Errors
    /// Returns an error when `tools` is missing or not an array.
    pub fn from_value(val: &Value) -> Result<Self, String> {
        let tools = val
            .get("tools")
            .and_then(Value::as_array)
            .ok_or_else(|| "survivors JSON must include a \"tools\" array".to_string())?
            .iter()
            .filter_map(|v| v.as_str().map(str::to_string))
            .collect();

        let mut properties = HashMap::new();
        if let Some(props) = val.get("properties").and_then(Value::as_object) {
            for (tool_id, names) in props {
                let list = names
                    .as_array()
                    .map(|arr| {
                        arr.iter()
                            .filter_map(|v| v.as_str().map(str::to_string))
                            .collect()
                    })
                    .unwrap_or_default();
                properties.insert(tool_id.clone(), list);
            }
        }

        let enums = val
            .get("enums")
            .and_then(Value::as_array)
            .map(|arr| {
                arr.iter()
                    .filter_map(|v| v.as_str().map(str::to_string))
                    .collect()
            })
            .unwrap_or_default();

        Ok(Self {
            tools,
            properties,
            enums,
        })
    }
}

fn property_rel_path(tool_id: &str, property_path: &str) -> String {
    let prefix = decomposed_prefix();
    let segments: Vec<&str> = property_path.split('.').collect();
    let mut parts = vec![
        prefix.trim_end_matches('/').to_string(),
        tool_id.to_string(),
    ];
    parts.extend(segments.iter().map(|s| (*s).to_string()));
    let last = parts.pop().unwrap_or_default();
    parts.push(format!("{last}{}", json_ext()));
    parts.join("/")
}

fn root_tool_rel(tool_id: &str) -> String {
    format!("{}{}{}", decomposed_prefix(), tool_id, json_ext())
}

fn enum_rel(enum_name: &str) -> String {
    format!("{}{}{}", decomposed_prefix(), enum_name, md_ext())
}

/// Resolve semantic survivor names to the internal `{json, md}` catalog survivor shape.
#[must_use]
pub fn resolve_survivors_from_names(index: &CatalogIndex, survivors: &NamedSurvivors) -> Value {
    let full_catalog = index.to_catalog_dict();
    let keep_tools: HashSet<&str> = survivors.tools.iter().map(String::as_str).collect();

    let json_entries = full_catalog
        .get("json")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let md_entries = full_catalog
        .get("md")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();

    let mut json_by_rel: HashMap<String, Value> = HashMap::new();
    for entry in json_entries {
        let Some(obj) = entry.as_object() else {
            continue;
        };
        let Some(fp) = obj.get("file_path").and_then(|v| v.as_str()) else {
            continue;
        };
        if let Some(rel) = paths::to_decomposed_key(fp) {
            json_by_rel.insert(rel, entry);
        }
    }

    let mut md_by_rel: HashMap<String, Value> = HashMap::new();
    for entry in md_entries {
        let Some(obj) = entry.as_object() else {
            continue;
        };
        let Some(fp) = obj.get("file_path").and_then(|v| v.as_str()) else {
            continue;
        };
        if let Some(rel) = paths::to_decomposed_key(fp) {
            md_by_rel.insert(rel, entry);
        }
    }

    let mut out_json = Vec::new();
    let mut out_md = Vec::new();

    for tool_id in &survivors.tools {
        let root_rel = root_tool_rel(tool_id);
        if let Some(entry) = json_by_rel.get(&root_rel) {
            out_json.push(entry.clone());
        }

        if let Some(props) = survivors.properties.get(tool_id) {
            for prop in props {
                let rel = property_rel_path(tool_id, prop);
                if let Some(entry) = json_by_rel.get(&rel) {
                    out_json.push(entry.clone());
                }
            }
        }
    }

    for enum_name in &survivors.enums {
        let rel = enum_rel(enum_name);
        if let Some(entry) = md_by_rel.get(&rel) {
            out_md.push(entry.clone());
        }
    }

    // Include enum md entries referenced by kept tools' schemas when listed in enums.
    let _ = keep_tools;

    json!({
        "json": out_json,
        "md": out_md,
    })
}

/// Build catalog in memory, resolve named survivors, and recompose pruned tool schemas.
#[must_use]
pub fn recompose_tools_from_names(
    tools: &[Value],
    survivors: &NamedSurvivors,
    ctx: &PolicyContext,
) -> Vec<Value> {
    let index = build_catalog_from_tools(tools);
    let survivor_data = resolve_survivors_from_names(&index, survivors);
    let build_catalog = index.to_catalog_dict();
    let mut store = DecomposedCatalog::from_catalog_index(&index);
    let process_groups = build_process_groups_options(ctx, &build_catalog, &store, None);
    let opts = RetrieveOptions {
        apply_decomposed_score_filter: false,
        process_groups,
    };
    retrieve_tools_from_catalog(ctx, &survivor_data, &build_catalog, &mut store, &opts)
}

#[cfg(test)]
#[allow(
    clippy::panic,
    clippy::unwrap_used,
    clippy::manual_let_else,
    clippy::option_if_let_else
)]
mod tests {
    use super::*;
    use crate::tool_entries::build_catalog_from_tools;
    use serde_json::json;

    #[test]
    fn resolve_survivors_maps_tool_and_property_names() {
        let tool = json!({
            "name": "Agent",
            "description": "Launch agents",
            "input_schema": {
                "type": "object",
                "properties": {
                    "prompt": {"type": "string"},
                    "model": {"type": "string", "enum": ["opus", "haiku"]},
                    "optional_field": {"type": "string", "description": "opt"}
                },
                "required": ["prompt"]
            }
        });
        let index = build_catalog_from_tools(&[tool]);
        let survivors = NamedSurvivors {
            tools: vec!["Agent".into()],
            properties: HashMap::from([("Agent".into(), vec!["optional_field".into()])]),
            enums: vec!["opus".into()],
        };
        let data = resolve_survivors_from_names(&index, &survivors);
        let json_arr = match data.get("json").and_then(|v| v.as_array()) {
            Some(arr) if !arr.is_empty() => arr,
            _ => panic!("json survivors"),
        };
        assert!(json_arr.iter().any(|e| {
            e.get("file_path")
                .and_then(|v| v.as_str())
                .is_some_and(|fp| fp.contains("Agent"))
        }));
        let md_arr = match data.get("md").and_then(|v| v.as_array()) {
            Some(arr) => arr,
            _ => panic!("md survivors"),
        };
        assert_eq!(md_arr.len(), 1);
    }

    #[test]
    fn recompose_drops_unlisted_tools() {
        let tools = vec![
            json!({
                "name": "Keep",
                "input_schema": {"type": "object", "properties": {"a": {"type": "string"}}, "required": ["a"]}
            }),
            json!({
                "name": "Drop",
                "input_schema": {"type": "object", "properties": {"b": {"type": "string"}}, "required": ["b"]}
            }),
        ];
        let survivors = NamedSurvivors {
            tools: vec!["Keep".into()],
            properties: HashMap::new(),
            enums: vec![],
        };
        let result = recompose_tools_from_names(&tools, &survivors, &PolicyContext::new());
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].get("name").and_then(|v| v.as_str()), Some("Keep"));
    }
}
