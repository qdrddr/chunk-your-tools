#!/usr/bin/env bash
# Recompose pruned MCP tool definitions from survivor lists.
#
# Run decompose first (creates the catalog under examples/catalog/):
#   ./examples/decompose.sh
#
# Input fixtures:
#   examples/input/tools.json              — full tool list (decomposed in memory with --input)
#   examples/catalog/                      — decomposed catalog on disk (with --catalog-dir)
#   examples/input/survivors-named.json    — semantic survivors (tools / properties / enums)
#   examples/input/survivors-legacy.json   — legacy {json, md} chunk lists (clear-your-tools shape)
#
# Prerequisites (pick one):
#   cargo install chunk-your-tools
#   cargo build -p chunk-your-tools --release   # from repo root
#   ./examples/recompose.sh --dev               # build/use target/release if needed
#
# Usage (from repo root or examples/):
#   ./examples/recompose.sh
#   ./examples/recompose.sh --dev
#   ./examples/decompose.sh
#   ./recompose.sh

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

CATALOG="${ROOT}/examples/catalog"
INPUT="${ROOT}/examples/input/tools.json"
OUT="${ROOT}/examples/output"
NAMED_SURVIVORS="${ROOT}/examples/input/survivors-named.json"
LEGACY_SURVIVORS="${ROOT}/examples/input/survivors-legacy.json"

if [[ ! -d "${CATALOG}/schemas/decomposed" ]]; then
	echo "Missing catalog at ${CATALOG}. Run ./examples/decompose.sh first." >&2
	exit 1
fi

CLI="$(chunk_your_tools_resolve_cli "$ROOT" "$DEV")"

mkdir -p "${OUT}"

# Semantic survivors: keep both tools, Agent.model, github.body, and two enum values.
# Required properties always survive; omitted tools are dropped entirely.
"${CLI}" recompose \
	--catalog-dir "${CATALOG}" \
	--survivors "${NAMED_SURVIVORS}" \
	--output "${OUT}/named.json"

# Drop the GitHub tool; keep only Agent with the model optional property.
jq '{
  tools: ["Agent"],
  properties: { Agent: ["model"] },
  enums: ["opus"]
}' "${NAMED_SURVIVORS}" >"${OUT}/survivors-agent-only.json"

"${CLI}" recompose \
	--catalog-dir "${CATALOG}" \
	--survivors "${OUT}/survivors-agent-only.json" \
	--output "${OUT}/agent-only.json"

# Legacy chunk survivors (json/md file_path lists from a reranker or pruner).
"${CLI}" recompose \
	--catalog-dir "${CATALOG}" \
	--survivors "${LEGACY_SURVIVORS}" \
	--output "${OUT}/legacy.json"

# Same legacy survivors with pruning policies (as used by clear-your-tools).
"${CLI}" recompose \
	--catalog-dir "${CATALOG}" \
	--survivors "${LEGACY_SURVIVORS}" \
	--output "${OUT}/legacy-with-policies.json" \
	--system-policy prune_optional \
	--mcp-policy prune_all \
	--tool-policy Agent=always_include

# Same semantic survivors, but decompose in memory from tools JSON (--input) instead of
# reading a pre-built catalog (--catalog-dir). Useful when you have tools.json only.
"${CLI}" recompose \
	--input "${INPUT}" \
	--survivors "${NAMED_SURVIVORS}" \
	--output "${OUT}/named-from-input.json"

# Force every tool to be treated as MCP (ignores mcp__ prefix). Agent is normally a
# system tool; with --tool-type mcp it gets mcp_policy instead.
"${CLI}" recompose \
	--catalog-dir "${CATALOG}" \
	--survivors "${LEGACY_SURVIVORS}" \
	--output "${OUT}/legacy-all-mcp.json" \
	--tool-type mcp \
	--mcp-policy prune_all \
	--system-policy always_include

# Force every tool to be treated as system. mcp__github__create_issue is normally MCP;
# with --tool-type system it gets system_policy instead.
"${CLI}" recompose \
	--catalog-dir "${CATALOG}" \
	--survivors "${LEGACY_SURVIVORS}" \
	--output "${OUT}/legacy-all-system.json" \
	--tool-type system \
	--system-policy prune_optional \
	--mcp-policy prune_all

echo "Wrote recomposed tools under ${OUT}/"
