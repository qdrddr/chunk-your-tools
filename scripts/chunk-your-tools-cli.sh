#!/usr/bin/env bash
# Example: decompose and recompose tools from debug/full_example.json using the release CLI.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

env -u CARGO_TARGET_DIR cargo build -p chunk-your-tools --release
CLI="${ROOT}/target/release/chunk-your-tools"
CATALOG="${ROOT}/.catalog"

mkdir -p "${CATALOG}"

jq '.body.tools' debug/full_example.json >"${CATALOG}/input.json"

"${CLI}" decompose --input "${CATALOG}/input.json" --output "${CATALOG}"

jq '{
  json: [.pruning.decomposed_catalog.rerank.json[]? | .score |= (tonumber)],
  md:   [.pruning.decomposed_catalog.rerank.md[]?   | .score |= (tonumber)]
}' debug/full_example.json >"${CATALOG}/survivors.json"

"${CLI}" recompose \
	--input "${CATALOG}/input.json" \
	--survivors "${CATALOG}/survivors.json" \
	--output "${CATALOG}/out.json" \
	--system-policy prune_optional \
	--mcp-policy prune_all \
	--tool-policy AskUserQuestion=always_include

echo "Wrote ${CATALOG}/out.json"
