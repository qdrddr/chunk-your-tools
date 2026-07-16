#!/usr/bin/env bash
# Sparse-clone chunk-your-tools at tag vX.Y.Z and render go.mod with a replace directive.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="${CHUNK_YOUR_TOOLS_RELEASE_VERSION:-1.0.0}"
TAG="v${VERSION}"
REPO="${CHUNK_YOUR_TOOLS_GIT_REPO:-https://github.com/qdrddr/chunk-your-tools.git}"
STAGING="${CHUNK_YOUR_TOOLS_GIT_STAGING:-${ROOT}/.staging/${VERSION}}"

if [[ ! -f "${STAGING}/sdk/go/go.mod" ]]; then
	echo "Fetching ${TAG} into ${STAGING}..." >&2
	rm -rf "$STAGING"
	git clone --depth 1 --branch "$TAG" --filter=blob:none --sparse "$REPO" "$STAGING"
	(
		cd "$STAGING"
		git sparse-checkout set . sdk/c sdk/go
	)
fi

sed -e "s|@CHUNK_YOUR_TOOLS_GIT_STAGING@|${STAGING}|g" \
	-e "s/@CHUNK_YOUR_TOOLS_GIT_VERSION@/${VERSION}/g" \
	"${ROOT}/go.mod.in" >"${ROOT}/go.mod"

# When developing inside the monorepo, overlay the fixed chunk-native-ensure tool onto the tag checkout.
MONOREPO_ROOT="$(cd "${ROOT}/../.." && pwd)"
if [[ -f "${MONOREPO_ROOT}/sdk/go/go.mod" && -f "${MONOREPO_ROOT}/Cargo.toml" ]]; then
	rsync -a "${MONOREPO_ROOT}/sdk/go/cmd/chunk-native-ensure/" "${STAGING}/sdk/go/cmd/chunk-native-ensure/"
	echo "Overlaid monorepo chunk-native-ensure onto ${TAG} checkout" >&2
fi

echo "Prepared staging=${STAGING}" >&2
printf '%s\n' "$STAGING"
