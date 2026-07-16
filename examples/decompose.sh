#!/usr/bin/env bash
# Decompose MCP tool definitions into a searchable catalog.
#
# Prerequisites (pick one):
#   cargo install chunk-your-tools
#   cargo build -p chunk-your-tools --release   # from repo root
#
# Usage (from repo root or examples/):
#   ./examples/decompose.sh
#   ./decompose.sh

set -euo pipefail

SCRIPT="${BASH_SOURCE[0]:-$0}"
EXAMPLES_DIR=""
for candidate in \
	"$(cd "$(dirname "$SCRIPT")" 2>/dev/null && pwd)" \
	"${PWD}/examples" \
	"$(cd "${PWD}/examples" 2>/dev/null && pwd)"; do
	if [[ -n "$candidate" && -f "${candidate}/_repo_root.sh" ]]; then
		EXAMPLES_DIR="$candidate"
		break
	fi
done
if [[ -z "$EXAMPLES_DIR" ]]; then
	echo "Could not locate examples/_repo_root.sh (run from repo root or examples/)" >&2
	exit 1
fi
# shellcheck disable=SC1091
source "${EXAMPLES_DIR}/_repo_root.sh"
ROOT="$(cyt_repo_root_from "$SCRIPT")"
cd "$ROOT"

INPUT="${ROOT}/examples/input/tools.json"
CATALOG="${ROOT}/examples/catalog"

if [[ -x "${ROOT}/target/release/chunk-your-tools" ]]; then
	CLI="${ROOT}/target/release/chunk-your-tools"
elif command -v chunk-your-tools >/dev/null 2>&1; then
	CLI=chunk-your-tools
else
	echo "Building chunk-your-tools (release)..." >&2
	env -u CARGO_TARGET_DIR cargo build -p chunk-your-tools --release
	CLI="${ROOT}/target/release/chunk-your-tools"
fi

"${CLI}" decompose --input "${INPUT}" --output "${CATALOG}"

echo "Catalog written to ${CATALOG}/schemas/decomposed/"
