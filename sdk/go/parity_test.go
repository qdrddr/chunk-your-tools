package chunkyourtools

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"testing"
)

func repoRoot(t *testing.T) string {
	t.Helper()
	_, file, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("runtime.Caller failed")
	}
	return filepath.Clean(filepath.Join(filepath.Dir(file), "../.."))
}

func pythonAvailable(t *testing.T) bool {
	t.Helper()
	root := repoRoot(t)
	if _, err := exec.LookPath("uv"); err != nil {
		return false
	}
	cmd := exec.Command("uv", "run", "--project", "sdk/python", "python", "-c", "import chunk_your_tools")
	cmd.Dir = root
	return cmd.Run() == nil
}

func pythonJSON(t *testing.T, script string) string {
	t.Helper()
	root := repoRoot(t)
	cmd := exec.Command("uv", "run", "--project", "sdk/python", "python", "-c", script)
	cmd.Dir = root
	out, err := cmd.Output()
	if err != nil {
		t.Fatalf("python reference failed: %v\n%s", err, cmd.Stderr)
	}
	return string(out)
}

func assertJSONEqual(t *testing.T, got, want string) {
	t.Helper()
	var gotVal any
	var wantVal any
	if err := json.Unmarshal([]byte(got), &gotVal); err != nil {
		t.Fatalf("got JSON invalid: %v\n%s", err, got)
	}
	if err := json.Unmarshal([]byte(want), &wantVal); err != nil {
		t.Fatalf("want JSON invalid: %v\n%s", err, want)
	}
	gotBytes, _ := json.Marshal(gotVal)
	wantBytes, _ := json.Marshal(wantVal)
	if string(gotBytes) != string(wantBytes) {
		t.Fatalf("JSON mismatch\ngot:  %s\nwant: %s", gotBytes, wantBytes)
	}
}

func TestParityBuildCatalogIndex(t *testing.T) {
	if os.Getenv("CHUNK_YOUR_TOOLS_SKIP_PARITY") == "1" {
		t.Skip("CHUNK_YOUR_TOOLS_SKIP_PARITY=1")
	}
	if !pythonAvailable(t) {
		t.Skip("python chunk_your_tools not available (run uv sync in sdk/python)")
	}

	want := pythonJSON(t, `
import json
from chunk_your_tools._native import build_catalog_index
print(json.dumps(build_catalog_index([], [])))
`)

	got, err := BuildCatalogIndex("[]", "[]")
	if err != nil {
		t.Fatalf("BuildCatalogIndex: %v", err)
	}
	assertJSONEqual(t, got, want)
}

func TestParityToolPolicies(t *testing.T) {
	if os.Getenv("CHUNK_YOUR_TOOLS_SKIP_PARITY") == "1" {
		t.Skip("CHUNK_YOUR_TOOLS_SKIP_PARITY=1")
	}
	if !pythonAvailable(t) {
		t.Skip("python chunk_your_tools not available")
	}

	want := pythonJSON(t, `
import json
from chunk_your_tools._native import tool_policies
print(json.dumps(tool_policies()))
`)

	got, err := ToolPolicies()
	if err != nil {
		t.Fatalf("ToolPolicies: %v", err)
	}
	assertJSONEqual(t, got, want)
}

func TestParityBatchToolPassThrough(t *testing.T) {
	if os.Getenv("CHUNK_YOUR_TOOLS_SKIP_PARITY") == "1" {
		t.Skip("CHUNK_YOUR_TOOLS_SKIP_PARITY=1")
	}
	if !pythonAvailable(t) {
		t.Skip("python chunk_your_tools not available")
	}

	want := pythonJSON(t, `
import json
from chunk_your_tools._native import policy_context_from_values, batch_tool_pass_through
cfg = {"pruning": {"tools": {"policy": {"system_tool": "always_include", "mcp_tool": "always_include"}}}}
ctx = policy_context_from_values(cfg)
print(json.dumps(batch_tool_pass_through(ctx, ["Agent", "grep"])))
`)

	ctx := `{"system_policy":"always_include","mcp_policy":"always_include"}`
	got, err := BatchToolPassThrough(ctx, `["Agent","grep"]`)
	if err != nil {
		t.Fatalf("BatchToolPassThrough: %v", err)
	}
	assertJSONEqual(t, got, want)
}

func TestParityToolPassThrough(t *testing.T) {
	if os.Getenv("CHUNK_YOUR_TOOLS_SKIP_PARITY") == "1" {
		t.Skip("CHUNK_YOUR_TOOLS_SKIP_PARITY=1")
	}
	if !pythonAvailable(t) {
		t.Skip("python chunk_your_tools not available")
	}

	want := pythonJSON(t, `
import json
from chunk_your_tools._native import policy_context_from_values, tool_pass_through
cfg = {"pruning": {"tools": {"policy": {"system_tool": "always_include", "mcp_tool": "always_include"}}}}
ctx = policy_context_from_values(cfg)
print(json.dumps(tool_pass_through(ctx, "Agent")))
`)

	ctx := `{"system_policy":"always_include","mcp_policy":"always_include"}`
	got, err := ToolPassThrough(ctx, "Agent")
	if err != nil {
		t.Fatalf("ToolPassThrough: %v", err)
	}
	gotBytes, _ := json.Marshal(got)
	assertJSONEqual(t, string(gotBytes), want)
}

func TestParityClassifyOptionalChunksBatch(t *testing.T) {
	if os.Getenv("CHUNK_YOUR_TOOLS_SKIP_PARITY") == "1" {
		t.Skip("CHUNK_YOUR_TOOLS_SKIP_PARITY=1")
	}
	if !pythonAvailable(t) {
		t.Skip("python chunk_your_tools not available")
	}

	want := pythonJSON(t, `
import json
from chunk_your_tools._native import classify_optional_chunks_batch
items = [{"file_path": "schemas/decomposed/mcp__test__read.json"}]
print(json.dumps(classify_optional_chunks_batch(items)))
`)

	items := `[{"file_path":"schemas/decomposed/mcp__test__read.json"}]`
	got, err := ClassifyOptionalChunksBatch(items)
	if err != nil {
		t.Fatalf("ClassifyOptionalChunksBatch: %v", err)
	}
	assertJSONEqual(t, got, want)
}

func TestParityEffectivePolicyByToolKind(t *testing.T) {
	if os.Getenv("CHUNK_YOUR_TOOLS_SKIP_PARITY") == "1" {
		t.Skip("CHUNK_YOUR_TOOLS_SKIP_PARITY=1")
	}
	if !pythonAvailable(t) {
		t.Skip("python chunk_your_tools not available")
	}

	want := pythonJSON(t, `
import json
from chunk_your_tools._native import PolicyContext, effective_policy
ctx = PolicyContext()
ctx.system_policy = "prune_optional"
ctx.mcp_policy = "prune_all"
ctx.tool_kind = "mcp"
print(json.dumps(effective_policy(ctx, "tools.demo.org.search")))
`)

	kind := ToolKindMcp
	ctx := PolicyContext{
		SystemPolicy: "prune_optional",
		McpPolicy:    "prune_all",
		ToolKind:     &kind,
	}
	ctxJSON, err := ctx.MarshalJSONString()
	if err != nil {
		t.Fatalf("MarshalJSONString: %v", err)
	}
	got, err := EffectivePolicy(ctxJSON, "tools.demo.org.search")
	if err != nil {
		t.Fatalf("EffectivePolicy: %v", err)
	}
	gotBytes, err := json.Marshal(got)
	if err != nil {
		t.Fatalf("marshal got: %v", err)
	}
	assertJSONEqual(t, string(gotBytes), want)
}

func TestScoringPolicyContextCopiesToolKind(t *testing.T) {
	kind := ToolKindMcp
	ctx := PolicyContext{
		SystemPolicy: "prune_optional_descriptions",
		McpPolicy:    "prune_all_descriptions",
		ToolKind:     &kind,
	}
	scoring, err := ScoringPolicyContext(ctx)
	if err != nil {
		t.Fatalf("ScoringPolicyContext: %v", err)
	}
	if scoring.ToolKind == nil || *scoring.ToolKind != ToolKindMcp {
		t.Fatalf("expected tool_kind mcp, got %#v", scoring.ToolKind)
	}
	if scoring.SystemPolicy != "prune_optional" || scoring.McpPolicy != "prune_all" {
		t.Fatalf("unexpected scoring policies: %#v", scoring)
	}
}

func TestParityCatalogIndexToolSchemaMetadata(t *testing.T) {
	if os.Getenv("CHUNK_YOUR_TOOLS_SKIP_PARITY") == "1" {
		t.Skip("CHUNK_YOUR_TOOLS_SKIP_PARITY=1")
	}
	if !pythonAvailable(t) {
		t.Skip("python chunk_your_tools not available")
	}

	want := pythonJSON(t, `
import json
from chunk_your_tools import catalog_index_tool_schema_metadata
print(json.dumps(catalog_index_tool_schema_metadata({"tools": [], "files": {}})))
`)

	got, err := CatalogIndexToolSchemaMetadata(`{"tools":[],"files":{}}`)
	if err != nil {
		t.Fatalf("CatalogIndexToolSchemaMetadata: %v", err)
	}
	assertJSONEqual(t, got, want)
}

func TestParityDecomposedMetadataEntryTypes(t *testing.T) {
	if os.Getenv("CHUNK_YOUR_TOOLS_SKIP_PARITY") == "1" {
		t.Skip("CHUNK_YOUR_TOOLS_SKIP_PARITY=1")
	}
	if !pythonAvailable(t) {
		t.Skip("python chunk_your_tools not available")
	}

	want := pythonJSON(t, `
import json
from chunk_your_tools import build_catalog_from_tools
tool = {
    "name": "Agent",
    "description": "Launch agents",
    "input_schema": {
        "type": "object",
        "properties": {
            "prompt": {"type": "string"},
            "model": {"type": "string", "enum": ["opus", "haiku"]},
        },
        "required": ["prompt"],
    },
}
index = build_catalog_from_tools([tool])
meta = index.tool_schema_metadata()
types = {
    entry["file_path"]: entry["type"]
    for entry in meta.get("decomposed") or []
}
print(json.dumps(types))
`)

	tool := map[string]any{
		"name":        "Agent",
		"description": "Launch agents",
		"input_schema": map[string]any{
			"type": "object",
			"properties": map[string]any{
				"prompt": map[string]any{"type": "string"},
				"model": map[string]any{
					"type": "string",
					"enum": []any{"opus", "haiku"},
				},
			},
			"required": []any{"prompt"},
		},
	}
	toolsJSON, err := json.Marshal([]any{tool})
	if err != nil {
		t.Fatalf("marshal tool: %v", err)
	}
	indexJSON, err := BuildCatalogFromTools(string(toolsJSON))
	if err != nil {
		t.Fatalf("BuildCatalogFromTools: %v", err)
	}
	metaJSON, err := CatalogIndexToolSchemaMetadata(indexJSON)
	if err != nil {
		t.Fatalf("CatalogIndexToolSchemaMetadata: %v", err)
	}

	var meta struct {
		Decomposed []struct {
			FilePath string `json:"file_path"`
			Type     string `json:"type"`
		} `json:"decomposed"`
	}
	if err := json.Unmarshal([]byte(metaJSON), &meta); err != nil {
		t.Fatalf("unmarshal metadata: %v", err)
	}
	got := make(map[string]string, len(meta.Decomposed))
	for _, entry := range meta.Decomposed {
		got[entry.FilePath] = entry.Type
	}
	gotBytes, err := json.Marshal(got)
	if err != nil {
		t.Fatalf("marshal got: %v", err)
	}
	assertJSONEqual(t, string(gotBytes), want)
}

func TestParityGetVersion(t *testing.T) {
	if os.Getenv("CHUNK_YOUR_TOOLS_SKIP_PARITY") == "1" {
		t.Skip("CHUNK_YOUR_TOOLS_SKIP_PARITY=1")
	}
	if !pythonAvailable(t) {
		t.Skip("python chunk_your_tools not available")
	}

	want := pythonJSON(t, `
import json
from chunk_your_tools import get_version
print(json.dumps(get_version()))
`)

	got, err := Version()
	if err != nil {
		t.Fatalf("Version: %v", err)
	}
	gotBytes, _ := json.Marshal(got)
	assertJSONEqual(t, string(gotBytes), want)
}
