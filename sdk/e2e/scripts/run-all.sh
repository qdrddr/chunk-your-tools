#!/usr/bin/env bash
# Run all registry E2E smokes (CI or local; requires packages on registries).
# Prefer ./run-local.sh for manual local runs — it adds defaults and per-target flags.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "${CHUNK_YOUR_TOOLS_RELEASE_VERSION:-}" && -n "${TAG:-}" ]]; then
	# shellcheck source=parse-version.sh
	eval "$("${ROOT}/scripts/parse-version.sh")"
fi

export CHUNK_YOUR_TOOLS_RELEASE_VERSION="${CHUNK_YOUR_TOOLS_RELEASE_VERSION:?set CHUNK_YOUR_TOOLS_RELEASE_VERSION or TAG}"

"${ROOT}/scripts/render-manifests.sh"

for target in rust python typescript go c; do
	"${ROOT}/scripts/run-target.sh" "$target"
done

echo "All registry E2E smokes passed."
