package chunkyourtools_test

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/qdrddr/chunk-your-tools/sdk/go/v2/moduleversion"
)

func TestModuleVersionMatchesCargoToml(t *testing.T) {
	t.Helper()

	cargoPath := filepath.Join("..", "..", "Cargo.toml")
	file, err := os.Open(cargoPath)
	if err != nil {
		t.Fatalf("open Cargo.toml: %v", err)
	}
	defer file.Close()

	var cargoVersion string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if strings.HasPrefix(line, "version = ") {
			cargoVersion = strings.Trim(strings.TrimPrefix(line, "version = "), `"`)
			break
		}
	}
	if err := scanner.Err(); err != nil {
		t.Fatalf("read Cargo.toml: %v", err)
	}
	if cargoVersion == "" {
		t.Fatal("Cargo.toml: missing version =")
	}
	if moduleversion.Version != cargoVersion {
		t.Fatalf("moduleversion.Version %q != Cargo.toml %q (run ./scripts/publish/sync-version.sh)",
			moduleversion.Version, cargoVersion)
	}
}
