#include <inttypes.h>
#include <stdio.h>

#include "examples/common.h"

int main(void) {
    char *index_out = NULL;
    const char *tools =
        "[{\"server\":\"srv\",\"tool\":\"search\",\"full_schema\":{"
        "\"inputSchema\":{\"type\":\"object\",\"properties\":{"
        "\"q\":{\"type\":\"string\"}},\"required\":[\"q\"]}}}]";
    const char *enums = "[]";

    if (!chunk_your_tools_example_ok(
            chunk_your_tools_build_catalog_index(tools, enums, &index_out),
            "chunk_your_tools_build_catalog_index")) {
        return 1;
    }
    char *catalog_index_json = chunk_your_tools_example_take(&index_out);

    ChunkYourToolsDecomposedCatalog *catalog = NULL;
    if (!chunk_your_tools_example_ok(
            chunk_your_tools_decomposed_catalog_from_catalog_index(
                catalog_index_json, &catalog),
            "chunk_your_tools_decomposed_catalog_from_catalog_index")) {
        chunk_your_tools_example_free(catalog_index_json);
        return 1;
    }

    char *dict_out = NULL;
    if (!chunk_your_tools_example_ok(
            chunk_your_tools_catalog_index_to_catalog_dict(
                catalog_index_json, "src/catalog", &dict_out),
            "chunk_your_tools_catalog_index_to_catalog_dict")) {
        chunk_your_tools_decomposed_catalog_free(catalog);
        chunk_your_tools_example_free(catalog_index_json);
        return 1;
    }
    char *data_json = chunk_your_tools_example_take(&dict_out);

    int64_t tool_count =
        chunk_your_tools_retrieve_catalog_tool_count(data_json);
    if (tool_count < 0) {
        fprintf(stderr,
                "chunk_your_tools_retrieve_catalog_tool_count failed\n");
        chunk_your_tools_decomposed_catalog_free(catalog);
        chunk_your_tools_example_free(catalog_index_json);
        chunk_your_tools_example_free(data_json);
        return 1;
    }

    char *retrieve_out = NULL;
    if (!chunk_your_tools_example_ok(chunk_your_tools_retrieve_tools(
                                         data_json, catalog, catalog_index_json,
                                         0, "[]", "{}", &retrieve_out),
                                     "chunk_your_tools_retrieve_tools")) {
        chunk_your_tools_decomposed_catalog_free(catalog);
        chunk_your_tools_example_free(catalog_index_json);
        chunk_your_tools_example_free(data_json);
        return 1;
    }
    char *result = chunk_your_tools_example_take(&retrieve_out);
    if (result == NULL || result[0] != '[') {
        fprintf(stderr, "retrieve result is not a JSON array\n");
        chunk_your_tools_example_free(result);
        chunk_your_tools_decomposed_catalog_free(catalog);
        chunk_your_tools_example_free(catalog_index_json);
        chunk_your_tools_example_free(data_json);
        return 1;
    }

    chunk_your_tools_example_free(result);
    chunk_your_tools_decomposed_catalog_free(catalog);
    chunk_your_tools_example_free(catalog_index_json);
    chunk_your_tools_example_free(data_json);

    printf("retrieve: decomposed catalog + retrieve_tools ok\n");
    return 0;
}
