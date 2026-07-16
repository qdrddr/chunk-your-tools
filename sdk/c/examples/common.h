#ifndef CHUNK_YOUR_TOOLS_EXAMPLE_COMMON_H
#define CHUNK_YOUR_TOOLS_EXAMPLE_COMMON_H

#include "include/chunk_your_tools.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int chunk_your_tools_example_ok(int code, const char *fn) {
    if (code == CHUNK_YOUR_TOOLS_OK) {
        return 1;
    }
    const char *err = chunk_your_tools_get_last_error();
    fprintf(stderr, "%s failed (%d): %s\n", fn, code,
            err ? err : "(no message)");
    return 0;
}

static char *chunk_your_tools_example_take(char **out) {
    char *s = *out;
    *out = NULL;
    return s;
}

static void chunk_your_tools_example_free(char *s) {
    if (s != NULL) {
        chunk_your_tools_free_string(s);
    }
}

#endif /* CHUNK_YOUR_TOOLS_EXAMPLE_COMMON_H */
