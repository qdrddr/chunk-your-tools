#!/usr/bin/env bash
# Decompose MCP tool definitions into a searchable catalog.
#
# Prerequisites (pick one):
#   cargo install chunk-your-tools
#   cargo build -p chunk-your-tools --release   # from repo root
#
# Usage:
#   ./examples/decompose.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

INPUT="${ROOT}/examples/tools.json"
OUTPUT="${ROOT}/examples/catalog"

if command -v chunk-your-tools >/dev/null 2>&1; then
	CLI=chunk-your-tools
elif [[ -x "${ROOT}/target/release/chunk-your-tools" ]]; then
	CLI="${ROOT}/target/release/chunk-your-tools"
else
	echo "Building chunk-your-tools (release)..." >&2
	env -u CARGO_TARGET_DIR cargo build -p chunk-your-tools --release
	CLI="${ROOT}/target/release/chunk-your-tools"
fi

"${CLI}" decompose --input "${INPUT}" --output "${OUTPUT}"

echo "Catalog written to ${OUTPUT}/schemas/decomposed/"
