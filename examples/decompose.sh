#!/usr/bin/env bash
# Decompose MCP tool definitions into a searchable catalog.
#
# Prerequisites (pick one):
#   cargo install chunk-your-tools
#   cargo build -p chunk-your-tools --release   # from repo root
#   ./examples/decompose.sh --dev               # build/use target/release if needed
#
# Usage (from repo root or examples/):
#   ./examples/decompose.sh
#   ./examples/decompose.sh --dev
#   ./decompose.sh

set -euo pipefail

DEV=0
while [[ $# -gt 0 ]]; do
	case "$1" in
	--dev)
		DEV=1
		shift
		;;
	*)
		echo "Unknown option: $1" >&2
		echo "Usage: $(basename "$0") [--dev]" >&2
		exit 1
		;;
	esac
done

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
# shellcheck source=examples/_repo_root.sh
source "${EXAMPLES_DIR}/_repo_root.sh"
ROOT="$(chunk_your_tools_repo_root_from "$SCRIPT")"
cd "$ROOT"

INPUT="${ROOT}/examples/input/tools.json"
CATALOG="${ROOT}/examples/catalog"

CLI="$(chunk_your_tools_resolve_cli "$ROOT" "$DEV")"

"${CLI}" decompose --input "${INPUT}" --output "${CATALOG}"

echo "Catalog written to ${CATALOG}/schemas/decomposed/"
