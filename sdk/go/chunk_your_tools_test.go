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
