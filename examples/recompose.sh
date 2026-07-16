#!/usr/bin/env bash
# Recompose pruned MCP tool definitions from survivor lists.
#
# Run decompose first (creates the catalog under examples/catalog/):
#   ./examples/decompose.sh
#
# Input fixtures:
#   examples/tools.json            — full tool list (Anthropic or MCP catalog shape)
#   examples/survivors-named.json  — semantic survivors (tools / properties / enums)
#   examples/survivors-legacy.json — legacy {json, md} chunk lists (clear-your-tools shape)
#
# Prerequisites (pick one):
#   cargo install chunk-your-tools
#   cargo build -p chunk-your-tools --release   # from repo root
#
# Usage:
#   ./examples/recompose.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

INPUT="${ROOT}/examples/tools.json"
CATALOG="${ROOT}/examples/catalog"
OUT="${ROOT}/examples/out"
NAMED_SURVIVORS="${ROOT}/examples/survivors-named.json"
LEGACY_SURVIVORS="${ROOT}/examples/survivors-legacy.json"

if command -v chunk-your-tools >/dev/null 2>&1; then
	CLI=chunk-your-tools
elif [[ -x "${ROOT}/target/release/chunk-your-tools" ]]; then
	CLI="${ROOT}/target/release/chunk-your-tools"
else
	echo "Building chunk-your-tools (release)..." >&2
	env -u CARGO_TARGET_DIR cargo build -p chunk-your-tools --release
	CLI="${ROOT}/target/release/chunk-your-tools"
fi

mkdir -p "${OUT}"

# Semantic survivors: keep both tools, Agent.model, github.body, and two enum values.
# Required properties always survive; omitted tools are dropped entirely.
"${CLI}" recompose \
	--input "${INPUT}" \
	--survivors "${NAMED_SURVIVORS}" \
	--output "${OUT}/named.json"

# Drop the GitHub tool; keep only Agent with the model optional property.
jq '{
  tools: ["Agent"],
  properties: { Agent: ["model"] },
  enums: ["opus"]
}' "${NAMED_SURVIVORS}" >"${OUT}/survivors-agent-only.json"

"${CLI}" recompose \
	--input "${INPUT}" \
	--survivors "${OUT}/survivors-agent-only.json" \
	--output "${OUT}/agent-only.json"

# Legacy chunk survivors (json/md file_path lists from a reranker or pruner).
# Decomposition runs in memory — a prior decompose step is optional but useful
# for inspecting the catalog that these paths refer to.
"${CLI}" recompose \
	--input "${INPUT}" \
	--survivors "${LEGACY_SURVIVORS}" \
	--output "${OUT}/legacy.json"

# Same legacy survivors with pruning policies (as used by clear-your-tools).
"${CLI}" recompose \
	--input "${INPUT}" \
	--survivors "${LEGACY_SURVIVORS}" \
	--output "${OUT}/legacy-with-policies.json" \
	--system-policy prune_optional \
	--mcp-policy prune_all \
	--tool-policy Agent=always_include

echo "Wrote recomposed tools under ${OUT}/"
