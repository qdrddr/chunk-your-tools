#include <inttypes.h>
#include <stdio.h>
#include <string.h>

#include "examples/common.h"

static int metadata_contains(const char *json, const char *needle) {
    return json != NULL && strstr(json, needle) != NULL;
}

int main(void) {
    char *out = NULL;
    const char *tools =
        "[{\"name\":\"Agent\",\"description\":\"Launch "
        "agents\",\"input_schema\":{"
        "\"type\":\"object\",\"properties\":{"
        "\"prompt\":{\"type\":\"string\"},"
        "\"model\":{\"type\":\"string\",\"enum\":[\"opus\",\"haiku\"]}"
        "},\"required\":[\"prompt\"]}}]";

    if (!chunk_your_tools_example_ok(
            chunk_your_tools_build_catalog_from_tools(tools, &out),
            "chunk_your_tools_build_catalog_from_tools")) {
        return 1;
    }

    char *index_json = chunk_your_tools_example_take(&out);
    if (index_json == NULL || strstr(index_json, "\"tools\"") == NULL) {
        fprintf(stderr, "unexpected catalog index JSON\n");
        chunk_your_tools_example_free(index_json);
        return 1;
    }

    char *meta_out = NULL;
    if (!chunk_your_tools_example_ok(
            chunk_your_tools_catalog_index_tool_schema_metadata(index_json,
                                                                &meta_out),
            "chunk_your_tools_catalog_index_tool_schema_metadata")) {
        chunk_your_tools_example_free(index_json);
        return 1;
    }
    char *meta_json = chunk_your_tools_example_take(&meta_out);
    if (!metadata_contains(meta_json, "\"type\":\"tool\"") ||
        !metadata_contains(meta_json, "\"type\":\"property\"") ||
        !metadata_contains(meta_json, "\"type\":\"enum\"")) {
        fprintf(stderr, "decomposed metadata missing type classification\n");
        chunk_your_tools_example_free(meta_json);
        chunk_your_tools_example_free(index_json);
        return 1;
    }
    chunk_your_tools_example_free(meta_json);

    const char *data = "{\"json\":[],\"md\":[]}";
    int64_t count = chunk_your_tools_catalog_tool_count(data);
    if (count != 0) {
        fprintf(stderr, "expected 0 tools, got %" PRId64 "\n", count);
        chunk_your_tools_example_free(index_json);
        return 1;
    }
    chunk_your_tools_example_free(index_json);

    printf("basic: build_catalog_index ok\n");
    return 0;
}
