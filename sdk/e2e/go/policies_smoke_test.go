package e2esupport_test

import (
	"strings"
	"testing"

	chunkyourtools "github.com/qdrddr/chunk-your-tools/sdk/go/v2"
)

func TestBatchToolPassThroughSmoke(t *testing.T) {
	ctx := `{"system_policy":"always_include","mcp_policy":"always_include"}`
	toolIDs := `["Agent","grep"]`
	got, err := chunkyourtools.BatchToolPassThrough(ctx, toolIDs)
	if err != nil {
		t.Fatalf("BatchToolPassThrough: %v", err)
	}
	if !strings.Contains(got, "true") {
		t.Fatalf("expected pass-through flags, got %s", got)
	}
}

func TestClassifyOptionalChunksBatchSmoke(t *testing.T) {
	items := `[{"file_path":"schemas/decomposed/mcp__test__read.json"}]`
	got, err := chunkyourtools.ClassifyOptionalChunksBatch(items)
	if err != nil {
		t.Fatalf("ClassifyOptionalChunksBatch: %v", err)
	}
	if !strings.Contains(got, `"system"`) || !strings.Contains(got, `"mcp"`) {
		t.Fatalf("unexpected batch classify JSON: %s", got)
	}
}

func TestToolPassThroughSmoke(t *testing.T) {
	ctx := `{"system_policy":"always_include","mcp_policy":"always_include"}`
	ok, err := chunkyourtools.ToolPassThrough(ctx, "Agent")
	if err != nil {
		t.Fatalf("ToolPassThrough: %v", err)
	}
	if !ok {
		t.Fatal("expected Agent to pass through with always_include policies")
	}
}
