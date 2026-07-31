package e2esupport_test

import (
	"encoding/json"
	"strings"
	"testing"

	chunkindexer "github.com/qdrddr/chunk-your-tools/sdk/go/v2"

	e2esupport "chunk-your-tools-go-registry-e2e"
)

func TestBuildCatalogIndexFromReleaseModule(t *testing.T) {
	tool := map[string]any{
		"id":      "mcp__test__foo",
		"server":  "test",
		"tool":    "mcp__test__foo",
		"summary": "A test tool",
		"full_schema": map[string]any{
			"id":          "mcp__test__foo",
			"name":        "mcp__test__foo",
			"description": "A test tool",
			"inputSchema": map[string]any{
				"type": "object",
				"properties": map[string]any{
					"required_field": map[string]any{"type": "string"},
					"optional_field": map[string]any{
						"type":        "string",
						"description": "opt",
					},
				},
				"required": []any{"required_field"},
			},
		},
	}
	toolsJSON, err := json.Marshal([]any{tool})
	if err != nil {
		t.Fatalf("marshal tool: %v", err)
	}

	indexJSON, err := chunkindexer.BuildCatalogIndex(string(toolsJSON), "[]")
	if err != nil {
		t.Fatalf("BuildCatalogIndex: %v", err)
	}
	if !strings.Contains(indexJSON, "schemas/decomposed/mcp__test__foo.json") {
		t.Fatalf("expected decomposed path in index JSON: %s", indexJSON)
	}

	metaJSON, err := chunkindexer.CatalogIndexToolSchemaMetadata(indexJSON)
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
	byPath := make(map[string]string, len(meta.Decomposed))
	for _, entry := range meta.Decomposed {
		byPath[entry.FilePath] = entry.Type
	}
	if byPath["schemas/decomposed/mcp__test__foo.json"] != "tool" {
		t.Fatalf("expected tool metadata type, got %#v", byPath)
	}
	if byPath["schemas/decomposed/mcp__test__foo/optional_field.json"] != "property" {
		t.Fatalf("expected property metadata type, got %#v", byPath)
	}
}

func TestDecomposeFromExampleFile(t *testing.T) {
	e2esupport.RunDecomposeFromExampleFile(t)
}
