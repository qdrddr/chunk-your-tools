#include <stdio.h>

#include "examples/common.h"

int main(void) {
    char *out = NULL;
    int code = chunk_your_tools_build_catalog_index(NULL, "[]", &out);
    if (code == CHUNK_YOUR_TOOLS_OK) {
        fprintf(stderr, "expected failure for NULL tools_json\n");
        chunk_your_tools_example_free(chunk_your_tools_example_take(&out));
        return 1;
    }

    const char *err = chunk_your_tools_get_last_error();
    if (err == NULL || err[0] == '\0') {
        fprintf(stderr, "expected thread-local error message\n");
        return 1;
    }

    chunk_your_tools_clear_error();
    if (chunk_your_tools_get_last_error() != NULL) {
        fprintf(stderr, "chunk_your_tools_clear_error did not clear message\n");
        return 1;
    }

    code = chunk_your_tools_build_catalog_index("not-json", "[]", &out);
    if (code == CHUNK_YOUR_TOOLS_OK) {
        fprintf(stderr, "expected JSON parse failure\n");
        chunk_your_tools_example_free(chunk_your_tools_example_take(&out));
        return 1;
    }

    printf("error_handling: failure paths ok\n");
    return 0;
}
