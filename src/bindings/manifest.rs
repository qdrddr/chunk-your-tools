//! Canonical manifest of chunk-your-tools C FFI exports.

/// One exported `chunk_your_tools_*` C symbol.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FfiExport {
    pub name: &'static str,
    pub category: &'static str,
}

/// All exported FFI symbols grouped by module category.
pub const EXPORTS: &[FfiExport] = &[
    export("chunk_your_tools_clear_error", "core"),
    export("chunk_your_tools_free_string", "core"),
    export("chunk_your_tools_get_last_error", "core"),
    export("chunk_your_tools_get_version", "core"),
    export("chunk_your_tools_build_catalog_index", "build"),
    export("chunk_your_tools_build_catalog_from_tools", "build"),
    export("chunk_your_tools_catalog_tool_count", "build"),
    export(
        "chunk_your_tools_anthropic_tools_to_catalog_entries",
        "build",
    ),
    export("chunk_your_tools_anthropic_tool_to_catalog_entry", "build"),
    export("chunk_your_tools_prepare_tool_entry", "build"),
    export("chunk_your_tools_truncate_description", "build"),
    export("chunk_your_tools_catalog_index_to_catalog_dict", "build"),
    export(
        "chunk_your_tools_catalog_index_tool_schema_metadata",
        "build",
    ),
    export("chunk_your_tools_catalog_builder_new", "build"),
    export("chunk_your_tools_catalog_builder_free", "build"),
    export("chunk_your_tools_catalog_builder_add_tool", "build"),
    export("chunk_your_tools_catalog_builder_get_tool_info", "build"),
    export("chunk_your_tools_catalog_builder_build_index", "build"),
    export("chunk_your_tools_catalog_builder_write_catalog", "build"),
    export("chunk_your_tools_catalog_builder_to_catalog_dict", "build"),
    export("chunk_your_tools_write_catalog_index", "build"),
    export("chunk_your_tools_load_catalog_index_from_dir", "build"),
    export("chunk_your_tools_configure_runtime_defaults", "runtime"),
    export("chunk_your_tools_runtime_decomposed_score", "runtime"),
    export("chunk_your_tools_runtime_enum_score", "runtime"),
    export("chunk_your_tools_runtime_rerank_score", "runtime"),
    export(
        "chunk_your_tools_runtime_empty_optional_fallback_k",
        "runtime",
    ),
    export("chunk_your_tools_runtime_default_system_policy", "runtime"),
    export("chunk_your_tools_runtime_default_mcp_policy", "runtime"),
    export("chunk_your_tools_configure_path_constants", "paths"),
    export("chunk_your_tools_collect_enums", "paths"),
    export("chunk_your_tools_to_decomposed_key", "paths"),
    export("chunk_your_tools_tool_id_from_decomposed_rel", "paths"),
    export("chunk_your_tools_get_root_tool_key", "paths"),
    export("chunk_your_tools_path_md_ext", "paths"),
    export("chunk_your_tools_path_json_ext", "paths"),
    export("chunk_your_tools_path_decomposed_prefix", "paths"),
    export("chunk_your_tools_path_decomposed_root", "paths"),
    export("chunk_your_tools_path_catalog_prefix", "paths"),
    export("chunk_your_tools_path_default_catalog_dir", "paths"),
    export("chunk_your_tools_path_builder_memory_only", "paths"),
    export("chunk_your_tools_path_write_catalog_prune", "paths"),
    export("chunk_your_tools_tool_policies", "policies"),
    export("chunk_your_tools_policy_context_from_values", "policies"),
    export("chunk_your_tools_effective_policy", "policies"),
    export("chunk_your_tools_tool_pass_through", "policies"),
    export("chunk_your_tools_batch_tool_pass_through", "policies"),
    export("chunk_your_tools_partition_catalog", "policies"),
    export("chunk_your_tools_merge_catalog", "policies"),
    export("chunk_your_tools_catalog_needs_partition", "policies"),
    export(
        "chunk_your_tools_catalog_needs_pruned_recompose",
        "policies",
    ),
    export("chunk_your_tools_request_pass_through", "policies"),
    export("chunk_your_tools_full_pass_through", "policies"),
    export("chunk_your_tools_needs_partition", "policies"),
    export("chunk_your_tools_needs_pruned_recompose", "policies"),
    export("chunk_your_tools_system_tools_pass_through", "policies"),
    export("chunk_your_tools_mcp_tools_pass_through", "policies"),
    export("chunk_your_tools_needs_description_reinstate", "policies"),
    export("chunk_your_tools_is_decomposed_tool_root_chunk", "policies"),
    export(
        "chunk_your_tools_is_decomposed_optional_property_chunk",
        "policies",
    ),
    export("chunk_your_tools_is_system_chunk", "policies"),
    export("chunk_your_tools_is_non_system_chunk", "policies"),
    export("chunk_your_tools_is_system_root_chunk", "policies"),
    export("chunk_your_tools_is_mcp_root_chunk", "policies"),
    export("chunk_your_tools_is_system_optional_chunk", "policies"),
    export("chunk_your_tools_is_mcp_optional_chunk", "policies"),
    export(
        "chunk_your_tools_is_direct_root_optional_property_chunk",
        "policies",
    ),
    export("chunk_your_tools_root_chunk_properties_empty", "policies"),
    export(
        "chunk_your_tools_classify_optional_chunks_batch",
        "policies",
    ),
    export("chunk_your_tools_stash_system_tools", "policies"),
    export("chunk_your_tools_restore_system_tools", "policies"),
    export("chunk_your_tools_stash_mcp_tools", "policies"),
    export("chunk_your_tools_restore_mcp_tools", "policies"),
    export("chunk_your_tools_merge_tools_preserving_order", "policies"),
    export("chunk_your_tools_split_anthropic_tools", "policies"),
    export("chunk_your_tools_filter_recompose_json_entries", "policies"),
    export(
        "chunk_your_tools_mitigate_empty_optional_properties",
        "policies",
    ),
    export(
        "chunk_your_tools_ensure_root_json_for_surviving_tools",
        "policies",
    ),
    export("chunk_your_tools_json_entries_for_recompose", "policies"),
    export(
        "chunk_your_tools_append_description_reinstate_entries",
        "policies",
    ),
    export("chunk_your_tools_is_description_policy", "policies"),
    export("chunk_your_tools_scoring_policy", "policies"),
    export(
        "chunk_your_tools_drop_recomposed_tools_with_empty_properties",
        "policies",
    ),
    export("chunk_your_tools_root_tool_id_from_chunk", "policies"),
    export("chunk_your_tools_chunk_tool_id", "policies"),
    export("chunk_your_tools_is_non_system_tool_id", "policies"),
    export("chunk_your_tools_is_system_tool_id", "policies"),
    export("chunk_your_tools_entries_for_policy", "policies"),
    export("chunk_your_tools_tools_for_catalog", "policies"),
    export("chunk_your_tools_system_required_enum_values", "policies"),
    export("chunk_your_tools_mcp_required_enum_values", "policies"),
    export("chunk_your_tools_required_enum_values_by_tool", "policies"),
    export("chunk_your_tools_optional_leaf_survived_rerank", "policies"),
    export("chunk_your_tools_anthropic_tool_is_system", "policies"),
    export("chunk_your_tools_anthropic_tool_is_mcp", "policies"),
    export(
        "chunk_your_tools_direct_root_optional_chunks_for_tool",
        "policies",
    ),
    export(
        "chunk_your_tools_tool_id_has_empty_decomposed_root",
        "policies",
    ),
    export(
        "chunk_your_tools_tool_id_had_empty_original_root_properties",
        "policies",
    ),
    export("chunk_your_tools_decomposed_catalog_new", "retrieve"),
    export("chunk_your_tools_decomposed_catalog_free", "retrieve"),
    export(
        "chunk_your_tools_decomposed_catalog_from_catalog_index",
        "retrieve",
    ),
    export(
        "chunk_your_tools_decomposed_catalog_from_catalog_dict",
        "retrieve",
    ),
    export("chunk_your_tools_decomposed_catalog_has_json", "retrieve"),
    export("chunk_your_tools_decomposed_catalog_get_json", "retrieve"),
    export("chunk_your_tools_load_catalog", "retrieve"),
    export("chunk_your_tools_retrieve_tools", "retrieve"),
    export("chunk_your_tools_retrieve_core", "retrieve"),
    export("chunk_your_tools_chunk_survivor_key", "retrieve"),
    export("chunk_your_tools_removed_chunks", "retrieve"),
    export("chunk_your_tools_retrieve_catalog_tool_count", "retrieve"),
    export("chunk_your_tools_resolve_build_catalog", "retrieve"),
];

const fn export(name: &'static str, category: &'static str) -> FfiExport {
    FfiExport { name, category }
}

/// N-API-only exports (Node/TypeScript SDK).
pub const NAPI_EXPORTS: &[&str] = &[
    "resolveBuildCatalog",
    "resolveSurvivorsFromNames",
    "recomposeToolsFromNames",
    "retrieveCatalogToolCount",
    "runtimeDefaultSystemPolicy",
    "runtimeDefaultMcpPolicy",
];

pub const CBINDGEN_STUB_SYMBOLS: &[&str] = &[
    "chunk_your_tools_full_pass_through",
    "chunk_your_tools_needs_description_reinstate",
    "chunk_your_tools_needs_partition",
    "chunk_your_tools_needs_pruned_recompose",
    "chunk_your_tools_system_tools_pass_through",
    "chunk_your_tools_mcp_tools_pass_through",
    "chunk_your_tools_tool_pass_through",
    "chunk_your_tools_is_decomposed_tool_root_chunk",
    "chunk_your_tools_is_decomposed_optional_property_chunk",
    "chunk_your_tools_is_system_chunk",
    "chunk_your_tools_is_non_system_chunk",
    "chunk_your_tools_is_system_root_chunk",
    "chunk_your_tools_is_mcp_root_chunk",
    "chunk_your_tools_is_system_optional_chunk",
    "chunk_your_tools_is_mcp_optional_chunk",
    "chunk_your_tools_is_direct_root_optional_property_chunk",
    "chunk_your_tools_root_chunk_properties_empty",
    "chunk_your_tools_stash_system_tools",
    "chunk_your_tools_restore_system_tools",
    "chunk_your_tools_stash_mcp_tools",
    "chunk_your_tools_restore_mcp_tools",
    "chunk_your_tools_path_md_ext",
    "chunk_your_tools_path_json_ext",
    "chunk_your_tools_path_decomposed_prefix",
    "chunk_your_tools_path_decomposed_root",
    "chunk_your_tools_path_catalog_prefix",
    "chunk_your_tools_path_default_catalog_dir",
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn exports_are_unique() {
        let mut seen = std::collections::HashSet::new();
        for exp in EXPORTS {
            assert!(seen.insert(exp.name), "duplicate export: {}", exp.name);
        }
    }

    #[test]
    fn cbindgen_stubs_listed_in_exports() {
        for name in CBINDGEN_STUB_SYMBOLS {
            assert!(
                EXPORTS.iter().any(|e| e.name == *name),
                "stub symbol missing from EXPORTS: {name}"
            );
        }
    }
}
