#!/usr/bin/env bash
# Build and run the git-tag smoke test outside the monorepo.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

export CGO_ENABLED=1
export CHUNK_YOUR_TOOLS_RELEASE_VERSION="${CHUNK_YOUR_TOOLS_RELEASE_VERSION:-0.6.4}"

STAGING="$("${ROOT}/prepare.sh")"
"${ROOT}/ensure-ffi.sh" "$STAGING" "$CHUNK_YOUR_TOOLS_RELEASE_VERSION"
eval "$("${ROOT}/ensure-ffi.sh" --print-cgo "$STAGING")"

go mod tidy
go build -o ./chunk-your-tools-go-git-smoke .
./chunk-your-tools-go-git-smoke
