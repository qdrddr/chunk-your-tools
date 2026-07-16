//! Tool schema decomposition and recomposition for MCP tool definitions.
#![allow(
    clippy::pub_use,
    clippy::module_name_repetitions,
    clippy::multiple_crate_versions
)]

pub mod build;
pub mod catalog_builder;
pub mod catalog_io;
pub mod json_util;
pub mod paths;
pub mod policies;
pub mod retrieve;
pub mod runtime_config;
pub mod survivors;
pub mod tool_entries;

#[cfg(feature = "python")]
pub mod python;

#[cfg(feature = "node")]
pub mod node;

#[cfg(feature = "ffi")]
pub mod bindings;

#[cfg(feature = "ffi")]
pub mod ffi;

pub use build::{
    CatalogIndex, build_catalog_index, catalog_tool_count, decompose_tool_schema, dedupe_enums,
    tool_schema_metadata_from_files,
};
pub use catalog_builder::CatalogBuilder;
pub use catalog_io::write_catalog_index;
pub use paths::{
    PathConfig, collect_enums, configure as configure_paths, get_root_tool_key,
    is_catalog_decomposed_path, snapshot as path_snapshot, to_decomposed_key,
    tool_id_from_decomposed_rel,
};
pub use policies::{
    PolicyContext, ToolPolicy, anthropic_tool_is_mcp, anthropic_tool_is_system,
    append_description_reinstate_entries, apply_per_tool_overrides, batch_tool_pass_through,
    catalog_needs_partition, catalog_needs_pruned_recompose, chunk_tool_id,
    direct_root_optional_chunks_for_tool, drop_recomposed_tools_with_empty_properties,
    effective_policy, entries_for_policy, filter_recompose_json_entries, full_pass_through,
    is_decomposed_optional_property_chunk, is_decomposed_tool_root_chunk, is_description_policy,
    is_direct_root_optional_property_chunk, is_mcp_optional_chunk, is_mcp_root_chunk,
    is_non_system_chunk, is_non_system_tool_id, is_system_chunk, is_system_optional_chunk,
    is_system_root_chunk, is_system_tool_id, merge_catalog, merge_tools_preserving_order,
    mitigate_empty_optional_properties, needs_description_reinstate,
    needs_empty_optional_mitigation, needs_partition, needs_pruned_recompose,
    optional_chunks_for_tool, optional_leaf_survived_rerank, parse_tool_policy,
    parse_tool_policy_pair, partition_catalog, per_tool_policies_from_value,
    policy_context_from_values, request_pass_through, restore_mcp_tools, restore_system_tools,
    root_chunk_properties_empty, root_tool_id_from_chunk, scoring_policy, split_anthropic_tools,
    stash_mcp_tools, stash_system_tools, system_required_enum_values, system_tools_pass_through,
    tool_id_had_empty_original_root_properties, tool_id_has_empty_decomposed_root,
    tool_pass_through, tools_for_catalog, uses_pruned_recompose,
};
pub use retrieve::{
    DecomposedCatalog, ProcessGroupsOptions, RemovedChunksOptions, RetrieveOptions,
    apply_description_reinstate_to_data, build_process_groups_options, chunk_survivor_key,
    climb_and_merge, deep_merge, extract_input_files, extract_scores, filter_and_sort_enums,
    group_files, load_catalog_from_dir, parse_json_input, process_groups, removed_chunks,
    resolve_build_catalog, retrieve_core, retrieve_tools_from_catalog,
};
pub use runtime_config::{
    RuntimeConfig, configure as configure_runtime, decomposed_score, default_mcp_policy,
    default_system_policy, empty_optional_fallback_k, enum_score, rerank_score,
    snapshot as runtime_snapshot,
};
pub use survivors::{NamedSurvivors, recompose_tools_from_names, resolve_survivors_from_names};
pub use tool_entries::{
    anthropic_tool_to_catalog_entry, anthropic_tools_to_catalog_entries, build_catalog_from_tools,
    is_catalog_tool_entry, normalize_tools_for_catalog, prepare_tool_entry, truncate_description,
};
