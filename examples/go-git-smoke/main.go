// Smoke test for github.com/qdrddr/chunk-your-tools/sdk/go consumed from a git tag checkout.
package main

import (
	"fmt"
	"log"
	"os"
	"strings"

	chunkyourtools "github.com/qdrddr/chunk-your-tools/sdk/go/v2"
)

func main() {
	libVersion, err := chunkyourtools.Version()
	if err != nil {
		log.Fatalf("Version(): %v (last error: %q)", err, chunkyourtools.LastError())
	}

	indexJSON, err := chunkyourtools.BuildCatalogIndex("[]", "[]")
	if err != nil {
		log.Fatalf("BuildCatalogIndex(): %v (last error: %q)", err, chunkyourtools.LastError())
	}

	fmt.Println("chunk-your-tools Go git smoke OK")
	fmt.Printf("  sdk module version: %s\n", chunkyourtools.ModuleVersion)
	fmt.Printf("  native lib version: %s\n", libVersion)
	fmt.Printf("  empty catalog index bytes: %d\n", len(indexJSON))
	if !strings.Contains(indexJSON, "tools") {
		log.Fatalf("unexpected index JSON: %s", indexJSON)
	}

	if wd, err := os.Getwd(); err == nil {
		fmt.Printf("  cwd: %s\n", wd)
	}
}

