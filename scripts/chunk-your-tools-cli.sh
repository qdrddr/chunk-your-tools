#!/usr/bin/env bash
# Example: decompose and recompose tools from examples/input fixtures using the release CLI.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

env -u CARGO_TARGET_DIR cargo build -p chunk-your-tools --release
CLI="${ROOT}/target/release/chunk-your-tools"
CATALOG="${ROOT}/.catalog"
TOOLS="${ROOT}/examples/input/tools.json"
SURVIVORS="${ROOT}/examples/input/survivors-legacy.json"

mkdir -p "${CATALOG}"

cp "${TOOLS}" "${CATALOG}/input.json"

"${CLI}" decompose --input "${CATALOG}/input.json" --output "${CATALOG}"

cp "${SURVIVORS}" "${CATALOG}/survivors.json"

"${CLI}" recompose \
	--input "${CATALOG}/input.json" \
	--survivors "${CATALOG}/survivors.json" \
	--output "${CATALOG}/out.json" \
	--system-policy prune_optional \
	--mcp-policy prune_all \
	--tool-policy AskUserQuestion=always_include

echo "Wrote ${CATALOG}/out.json"
