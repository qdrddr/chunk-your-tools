#include <stdio.h>
#include <string.h>

#include "examples/common.h"

int main(void) {
    char *policies_out = NULL;
    if (!chunk_your_tools_example_ok(
            chunk_your_tools_tool_policies(&policies_out),
            "chunk_your_tools_tool_policies")) {
        return 1;
    }
    char *policies = chunk_your_tools_example_take(&policies_out);
    if (policies == NULL || strstr(policies, "prune_optional") == NULL) {
        fprintf(stderr, "unexpected tool policies JSON\n");
        chunk_your_tools_example_free(policies);
        return 1;
    }
    chunk_your_tools_example_free(policies);

    char *ctx_out = NULL;
    const char *ctx_values = "{\"system_policy\":\"prune_optional\","
                             "\"mcp_policy\":\"prune_all\"}";
    if (!chunk_your_tools_example_ok(
            chunk_your_tools_policy_context_from_values(ctx_values, &ctx_out),
            "chunk_your_tools_policy_context_from_values")) {
        return 1;
    }
    char *ctx = chunk_your_tools_example_take(&ctx_out);

    const char *data =
        "{\"json\":[],\"md\":[],\"tools\":[{\"name\":\"Agent\"}]}";
    char *partition_out = NULL;
    if (!chunk_your_tools_example_ok(
            chunk_your_tools_partition_catalog(data, ctx, &partition_out),
            "chunk_your_tools_partition_catalog")) {
        chunk_your_tools_example_free(ctx);
        return 1;
    }
    char *partitioned = chunk_your_tools_example_take(&partition_out);

    char *merged_out = NULL;
    if (!chunk_your_tools_example_ok(
            chunk_your_tools_merge_catalog(partitioned, "{}", &merged_out),
            "chunk_your_tools_merge_catalog")) {
        chunk_your_tools_example_free(partitioned);
        chunk_your_tools_example_free(ctx);
        return 1;
    }
    chunk_your_tools_example_free(chunk_your_tools_example_take(&merged_out));
    chunk_your_tools_example_free(partitioned);
    chunk_your_tools_example_free(ctx);

    const char *tool_ids = "[\"Agent\",\"grep\"]";
    char *batch_out = NULL;
    const char *pass_ctx = "{\"system_policy\":\"always_include\",\"mcp_"
                           "policy\":\"always_include\"}";
    if (!chunk_your_tools_example_ok(
            chunk_your_tools_batch_tool_pass_through(pass_ctx, tool_ids,
                                                     &batch_out),
            "chunk_your_tools_batch_tool_pass_through")) {
        return 1;
    }
    char *batch_flags = chunk_your_tools_example_take(&batch_out);
    if (batch_flags == NULL || strstr(batch_flags, "true") == NULL) {
        fprintf(stderr, "unexpected batch_tool_pass_through JSON\n");
        chunk_your_tools_example_free(batch_flags);
        return 1;
    }
    chunk_your_tools_example_free(batch_flags);

    char *policy_out = NULL;
    const char *mcp_ctx = "{\"system_policy\":\"prune_optional\","
                          "\"mcp_policy\":\"prune_all\","
                          "\"tool_kind\":\"mcp\"}";
    if (!chunk_your_tools_example_ok(
            chunk_your_tools_effective_policy(mcp_ctx, "tools.demo.org.search",
                                              &policy_out),
            "chunk_your_tools_effective_policy tool_kind")) {
        return 1;
    }
    char *policy = chunk_your_tools_example_take(&policy_out);
    if (policy == NULL || strcmp(policy, "prune_all") != 0) {
        fprintf(stderr, "unexpected effective_policy with tool_kind=mcp: %s\n",
                policy ? policy : "(null)");
        chunk_your_tools_example_free(policy);
        return 1;
    }
    chunk_your_tools_example_free(policy);

    if (chunk_your_tools_is_description_policy("prune_optional_descriptions") !=
        1) {
        fprintf(stderr, "chunk_your_tools_is_description_policy failed\n");
        return 1;
    }

    printf("policies: partition/merge ok\n");
    return 0;
}
