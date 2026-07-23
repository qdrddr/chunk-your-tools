/**
 * @file chunk_your_tools.h
 * @brief chunk-your-tools C FFI interface
 *
 * Tool schema decomposition and recomposition for MCP tool definitions.
 *
 * # Memory Management
 *
 * - Strings returned via `char**` out parameters MUST be freed with `chunk_your_tools_free_string()`.
 * - Opaque handles (`ChunkYourToolsCatalogBuilder`, `ChunkYourToolsDecomposedCatalog`)
 *   MUST be freed with their matching `chunk_your_tools_*_free()` function.
 * - Input C strings remain owned by the caller.
 *
 * # Thread Safety
 *
 * Error messages are stored in thread-local storage. Call `chunk_your_tools_get_last_error()`
 * from the same thread that received a non-zero error code.
 *
 * # Return Conventions
 *
 * - `CHUNK_YOUR_TOOLS_OK` (0) on success for status functions.
 * - Negative error codes on failure; see `chunk_your_tools_get_last_error()`.
 * - JSON outputs: int return code + `char**` out param.
 * - Boolean queries: 1 true, 0 false, negative on error (or `int*` out with `CHUNK_YOUR_TOOLS_OK`).
 */


#ifndef CHUNK_YOUR_TOOLS_H
#define CHUNK_YOUR_TOOLS_H

#pragma once

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

/*
 Success return code.
 */
#define CHUNK_YOUR_TOOLS_OK 0

/*
 Null pointer argument error.
 */
#define CHUNK_YOUR_TOOLS_ERR_NULL_PTR -1

/*
 Invalid UTF-8 encoding error.
 */
#define CHUNK_YOUR_TOOLS_ERR_INVALID_UTF8 -2

/*
 JSON parse or serialization error.
 */
#define CHUNK_YOUR_TOOLS_ERR_JSON -3

/*
 Memory allocation error.
 */
#define CHUNK_YOUR_TOOLS_ERR_ALLOC -4

/*
 I/O or filesystem error.
 */
#define CHUNK_YOUR_TOOLS_ERR_IO -5

/*
 Invalid opaque handle.
 */
#define CHUNK_YOUR_TOOLS_ERR_INVALID_HANDLE -6

/*
 Internal panic (caught at FFI boundary).
 */
#define CHUNK_YOUR_TOOLS_ERR_PANIC -7

/*
 Invalid argument / value error.
 */
#define CHUNK_YOUR_TOOLS_ERR_INVALID_ARG -8

/*
 Opaque catalog builder handle.
 */
typedef struct ChunkYourToolsCatalogBuilder ChunkYourToolsCatalogBuilder;

/*
 Opaque in-memory decomposed catalog handle.
 */
typedef struct ChunkYourToolsDecomposedCatalog ChunkYourToolsDecomposedCatalog;

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

int chunk_your_tools_full_pass_through(const char *ctx_json);

int chunk_your_tools_needs_description_reinstate(const char *ctx_json);

int chunk_your_tools_needs_partition(const char *ctx_json);

int chunk_your_tools_needs_pruned_recompose(const char *ctx_json);

int chunk_your_tools_system_tools_pass_through(const char *ctx_json);

int chunk_your_tools_mcp_tools_pass_through(const char *ctx_json);

int chunk_your_tools_tool_pass_through(const char *ctx_json, const char *tool_id);

int chunk_your_tools_is_decomposed_tool_root_chunk(const char *item_json);

int chunk_your_tools_is_decomposed_optional_property_chunk(const char *item_json);

int chunk_your_tools_is_system_chunk(const char *item_json);

int chunk_your_tools_is_non_system_chunk(const char *item_json);

int chunk_your_tools_is_system_root_chunk(const char *item_json);

int chunk_your_tools_is_mcp_root_chunk(const char *item_json);

int chunk_your_tools_is_system_optional_chunk(const char *item_json);

int chunk_your_tools_is_mcp_optional_chunk(const char *item_json);

int chunk_your_tools_is_direct_root_optional_property_chunk(const char *item_json);

int chunk_your_tools_root_chunk_properties_empty(const char *item_json);

int chunk_your_tools_stash_system_tools(const char *input_json, char **out);

int chunk_your_tools_restore_system_tools(const char *input_json, char **out);

int chunk_your_tools_stash_mcp_tools(const char *input_json, char **out);

int chunk_your_tools_restore_mcp_tools(const char *input_json, char **out);

int chunk_your_tools_path_md_ext(char **out);

int chunk_your_tools_path_json_ext(char **out);

int chunk_your_tools_path_decomposed_prefix(char **out);

int chunk_your_tools_path_decomposed_root(char **out);

int chunk_your_tools_path_catalog_prefix(char **out);

int chunk_your_tools_path_default_catalog_dir(char **out);

/*
 Count tools in a catalog dict JSON.

 # Safety

 `data_json` must be a valid null-terminated UTF-8 C string, or null (returns -1).
 */
long chunk_your_tools_catalog_tool_count(const char *data_json);

/*
 Build a catalog index from tools and enums JSON arrays.

 # Safety

 `tools_json`, `enums_json`, and `out` must be valid pointers. `out` receives an
 allocated JSON string that the caller must free with [`chunk_your_tools_free_string`].
 */
int chunk_your_tools_build_catalog_index(const char *tools_json,
                                         const char *enums_json,
                                         char **out);

/*
 Convert Anthropic tools to catalog entries and enums.
 */
int chunk_your_tools_anthropic_tools_to_catalog_entries(const char *tools_json, char **out);

/*
 Build catalog index from normalized tool entries.
 */
int chunk_your_tools_build_catalog_from_tools(const char *tools_json, char **out);

/*
 Prepare a single tool catalog entry.
 */
int chunk_your_tools_prepare_tool_entry(const char *server_name,
                                        const char *name,
                                        const char *description,
                                        const char *input_schema_json,
                                        char **out);

/*
 Convert one Anthropic tool to a catalog entry. Writes null to `out` when none.
 */
int chunk_your_tools_anthropic_tool_to_catalog_entry(const char *tool_json, char **out);

/*
 Truncate a tool description to a token budget.
 */
int chunk_your_tools_truncate_description(const char *description,
                                          unsigned long max_tokens,
                                          char **out);

/*
 Convert catalog index JSON to catalog dict for retrieval.
 */
int chunk_your_tools_catalog_index_to_catalog_dict(const char *index_json,
                                                   const char *catalog_prefix,
                                                   char **out);

/*
 Return cached full/decomposed tool schema token metadata from catalog index JSON.
 */
int chunk_your_tools_catalog_index_tool_schema_metadata(const char *index_json, char **out);

int chunk_your_tools_catalog_builder_new(int memory_only,
                                         const char *output_dir,
                                         struct ChunkYourToolsCatalogBuilder **out);

void chunk_your_tools_catalog_builder_free(struct ChunkYourToolsCatalogBuilder *builder);

int chunk_your_tools_catalog_builder_add_tool(struct ChunkYourToolsCatalogBuilder *builder,
                                              const char *entry_json);

int chunk_your_tools_catalog_builder_get_tool_info(const struct ChunkYourToolsCatalogBuilder *builder,
                                                   const char *server_name,
                                                   const char *tool_name,
                                                   char **out);

int chunk_your_tools_catalog_builder_build_index(struct ChunkYourToolsCatalogBuilder *builder,
                                                 char **out);

int chunk_your_tools_catalog_builder_write_catalog(struct ChunkYourToolsCatalogBuilder *builder,
                                                   char **out);

int chunk_your_tools_catalog_builder_to_catalog_dict(struct ChunkYourToolsCatalogBuilder *builder,
                                                     const char *catalog_prefix,
                                                     char **out);

int chunk_your_tools_load_catalog_index_from_dir(const char *dir_path, char **out);

int chunk_your_tools_write_catalog_index(const char *index_json, const char *output_dir, int prune);

/*
 Get the last error message for the current thread.

 Returns NULL if no error occurred. Valid until the next `chunk_your_tools_*` call on this thread.

 # Safety

 No pointer arguments; safe to call from C when linked against this library.
 */
const char *chunk_your_tools_get_last_error(void);

/*
 Clear the last error for the current thread.

 # Safety

 No pointer arguments; safe to call from C when linked against this library.
 */
void chunk_your_tools_clear_error(void);

/*
 Free a string allocated by `chunk_your_tools_*` functions. NULL is safe.

 # Safety

 `s` must be null or a pointer previously returned by a `chunk_your_tools_*` out-parameter.
 */
void chunk_your_tools_free_string(char *s);

/*
 Return the library version string (caller must free with `chunk_your_tools_free_string`).

 # Safety

 `out` must be a valid pointer to a `char*` that receives an allocated string.
 */
int chunk_your_tools_get_version(char **out);

int chunk_your_tools_configure_path_constants(const char *md_ext,
                                              const char *json_ext,
                                              const char *decomposed_prefix,
                                              const char *decomposed_root,
                                              const char *catalog_prefix,
                                              const char *default_catalog_dir,
                                              int builder_memory_only,
                                              int write_catalog_prune);

int chunk_your_tools_collect_enums(const char *schema_json, char **out);

int chunk_your_tools_to_decomposed_key(const char *file_path, char **out);

int chunk_your_tools_tool_id_from_decomposed_rel(const char *rel_path, char **out);

int chunk_your_tools_get_root_tool_key(const char *file_path, char **out);

int chunk_your_tools_path_builder_memory_only(void);

int chunk_your_tools_path_write_catalog_prune(void);

int chunk_your_tools_tool_policies(char **out);

int chunk_your_tools_policy_context_from_values(const char *config_json, char **out);

int chunk_your_tools_effective_policy(const char *ctx_json, const char *tool_id, char **out);

int chunk_your_tools_batch_tool_pass_through(const char *ctx_json,
                                             const char *tool_ids_json,
                                             char **out);

int chunk_your_tools_partition_catalog(const char *data_json, const char *ctx_json, char **out);

int chunk_your_tools_merge_catalog(const char *processed_json, const char *pinned_json, char **out);

int chunk_your_tools_catalog_needs_partition(const char *data_json, const char *ctx_json);

int chunk_your_tools_catalog_needs_pruned_recompose(const char *data_json, const char *ctx_json);

int chunk_your_tools_request_pass_through(const char *ctx_json, const char *tools_json);

int chunk_your_tools_filter_recompose_json_entries(const char *json_list_json,
                                                   const char *ctx_json,
                                                   double rerank_score,
                                                   int use_default_rerank_score,
                                                   const char *llm_selected_paths_json,
                                                   char **out);

int chunk_your_tools_mitigate_empty_optional_properties(const char *entries_json,
                                                        const char *catalog_index_json,
                                                        const char *ctx_json,
                                                        const char *post_rerank_scored_json,
                                                        const char *pipeline_json,
                                                        char **out);

int chunk_your_tools_append_description_reinstate_entries(const char *entries_json,
                                                          const char *build_catalog_json,
                                                          const char *catalog_index_json,
                                                          const char *ctx_json,
                                                          char **out);

int chunk_your_tools_is_description_policy(const char *policy);

int chunk_your_tools_scoring_policy(const char *policy, char **out);

int chunk_your_tools_drop_recomposed_tools_with_empty_properties(const char *tools_json,
                                                                 const char *catalog_index_json,
                                                                 const char *ctx_json,
                                                                 char **out);

int chunk_your_tools_root_tool_id_from_chunk(const char *item_json, char **out);

int chunk_your_tools_chunk_tool_id(const char *item_json, char **out);

int chunk_your_tools_is_non_system_tool_id(const char *tool_id);

int chunk_your_tools_is_system_tool_id(const char *tool_id);

int chunk_your_tools_merge_tools_preserving_order(const char *original_json,
                                                  const char *pruned_by_name_json,
                                                  const char *stashed_by_name_json,
                                                  char **out);

int chunk_your_tools_split_anthropic_tools(const char *tools_json, char **out);

int chunk_your_tools_entries_for_policy(const char *ctx_json,
                                        const char *all_entries_json,
                                        char **out);

int chunk_your_tools_tools_for_catalog(const char *ctx_json, const char *tools_json, char **out);

int chunk_your_tools_system_required_enum_values(const char *data_json, char **out);

int chunk_your_tools_mcp_required_enum_values(const char *data_json, char **out);

int chunk_your_tools_required_enum_values_by_tool(const char *data_json, char **out);

int chunk_your_tools_optional_leaf_survived_rerank(const char *item_json,
                                                   const char *ctx_json,
                                                   double rerank_score,
                                                   int use_default_rerank_score,
                                                   const char *llm_selected_paths_json,
                                                   int *out);

int chunk_your_tools_anthropic_tool_is_system(const char *tool_json);

int chunk_your_tools_anthropic_tool_is_mcp(const char *tool_json);

int chunk_your_tools_direct_root_optional_chunks_for_tool(const char *items_json,
                                                          const char *tool_id,
                                                          char **out);

int chunk_your_tools_tool_id_has_empty_decomposed_root(const char *catalog_index_json,
                                                       const char *tool_id,
                                                       int *out);

int chunk_your_tools_tool_id_had_empty_original_root_properties(const char *catalog_index_json,
                                                                const char *tool_id,
                                                                int *out);

/*
 Classify optional chunks for many catalog items in one pass.

 Returns JSON `{"system":[bool,...],"mcp":[bool,...]}`.

 # Safety

 `items_json` must be a JSON array; `out` must be non-null.
 */
int chunk_your_tools_classify_optional_chunks_batch(const char *items_json, char **out);

int chunk_your_tools_decomposed_catalog_new(struct ChunkYourToolsDecomposedCatalog **out);

void chunk_your_tools_decomposed_catalog_free(struct ChunkYourToolsDecomposedCatalog *catalog);

int chunk_your_tools_decomposed_catalog_from_catalog_index(const char *index_json,
                                                           struct ChunkYourToolsDecomposedCatalog **out);

int chunk_your_tools_decomposed_catalog_from_catalog_dict(const char *data_json,
                                                          struct ChunkYourToolsDecomposedCatalog **out);

int chunk_your_tools_decomposed_catalog_has_json(const struct ChunkYourToolsDecomposedCatalog *catalog,
                                                 const char *key);

int chunk_your_tools_decomposed_catalog_get_json(const struct ChunkYourToolsDecomposedCatalog *catalog,
                                                 const char *key,
                                                 char **out);

int chunk_your_tools_retrieve_core(const char *data_json,
                                   const char *store_json,
                                   const char *survivor_json,
                                   int apply_decomposed_score_filter,
                                   const char *policy_options_json,
                                   char **out);

int chunk_your_tools_load_catalog(const char *dir_path, char **out);

int chunk_your_tools_chunk_survivor_key(const char *item_json, const char *section, char **out);

int chunk_your_tools_removed_chunks(const char *full_catalog_json,
                                    const char *surviving_json,
                                    int apply_decomposed_score_filter,
                                    char **out);

int chunk_your_tools_retrieve_tools(const char *data_json,
                                    struct ChunkYourToolsDecomposedCatalog *catalog,
                                    const char *catalog_index_json,
                                    int apply_decomposed_score_filter,
                                    const char *preserve_values_json,
                                    const char *ctx_json,
                                    char **out);

long chunk_your_tools_retrieve_catalog_tool_count(const char *data_json);

int chunk_your_tools_resolve_build_catalog(const char *catalog_json,
                                           const char *survivor_json,
                                           char **out);

int chunk_your_tools_configure_runtime_defaults(double decomposed_score,
                                                double enum_score,
                                                double rerank_score,
                                                uintptr_t empty_optional_fallback_k,
                                                const char *default_system_policy,
                                                const char *default_mcp_policy);

double chunk_your_tools_runtime_decomposed_score(void);

double chunk_your_tools_runtime_enum_score(void);

double chunk_your_tools_runtime_rerank_score(void);

uintptr_t chunk_your_tools_runtime_empty_optional_fallback_k(void);

int chunk_your_tools_runtime_default_system_policy(char **out);

int chunk_your_tools_runtime_default_mcp_policy(char **out);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  /* CHUNK_YOUR_TOOLS_H */
