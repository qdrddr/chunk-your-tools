package chunkyourtools

import "github.com/qdrddr/chunk-your-tools/sdk/go/v2/moduleversion"

// ModuleVersion is the Go SDK module semver (synced by scripts/sync-version.sh).
// For the native chunk-your-tools library version, use Version().
const ModuleVersion = moduleversion.Version
