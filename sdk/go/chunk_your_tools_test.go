package chunkyourtools

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestBuildCatalogIndexSmoke(t *testing.T) {
	indexJSON, err := BuildCatalogIndex("[]", "[]")
	if err != nil {
		t.Fatalf("BuildCatalogIndex: %v", err)
	}
	if !strings.Contains(indexJSON, `"tools"`) {
		t.Fatalf("expected tools key in index JSON: %s", indexJSON)
	}
}

func TestCatalogToolCountSmoke(t *testing.T) {
	count, err := CatalogToolCount(`{"json":[],"md":[]}`)
	if err != nil {
		t.Fatalf("CatalogToolCount: %v", err)
	}
	if count != 0 {
		t.Fatalf("expected 0 tools, got %d", count)
	}
}

func TestToolPoliciesSmoke(t *testing.T) {
	policiesJSON, err := ToolPolicies()
	if err != nil {
		t.Fatalf("ToolPolicies: %v", err)
	}
	var policies []string
	if err := json.Unmarshal([]byte(policiesJSON), &policies); err != nil {
		t.Fatalf("unmarshal policies: %v", err)
	}
	if len(policies) != 5 {
		t.Fatalf("expected 5 policies, got %d", len(policies))
	}
}

func TestRuntimeDefaultsSmoke(t *testing.T) {
	if err := ConfigureRuntimeDefaults(0.5, 0.2, 0.003, 3, "prune_optional", "prune_all"); err != nil {
		t.Fatalf("ConfigureRuntimeDefaults: %v", err)
	}
	if RuntimeDecomposedScore() != 0.5 {
		t.Fatalf("unexpected decomposed score: %v", RuntimeDecomposedScore())
	}
}

func TestDecomposedMetadataEntryTypes(t *testing.T) {
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

	byPath := make(map[string]string, len(meta.Decomposed))
	for _, entry := range meta.Decomposed {
		byPath[entry.FilePath] = entry.Type
	}

	cases := map[string]string{
		"schemas/decomposed/Agent.json":       "tool",
		"schemas/decomposed/Agent/model.json": "property",
		"schemas/decomposed/haiku.md":         "enum",
		"schemas/decomposed/opus.md":          "enum",
	}
	for path, want := range cases {
		if got := byPath[path]; got != want {
			t.Fatalf("metadata type for %s: got %q, want %q", path, got, want)
		}
	}
}
