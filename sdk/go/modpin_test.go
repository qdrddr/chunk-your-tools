package chunkyourtools_test

import (
	"os"
	"path/filepath"
	"testing"
)

// Dev linters and scanners run via pinned `go run ...@version` in
// scripts/pre-commit-hooks/go-sdk-precommit.sh. A nested tools/go.mod would
// bloat Snyk scans without helping the published SDK.
func TestNoDevToolsModule(t *testing.T) {
	t.Helper()

	toolsMod := filepath.Join("tools", "go.mod")
	if _, err := os.Stat(toolsMod); err == nil {
		t.Fatalf("%s must not exist: dev tools are external (see go-sdk-precommit.sh)", toolsMod)
	}
}
