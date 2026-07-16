#!/usr/bin/env bash
# Create and push sdk/go/vX.Y.Z if missing (same commit as vX.Y.Z).
set -euo pipefail

VERSION="${1:-${CHUNK_YOUR_TOOLS_RELEASE_VERSION:-}}"
if [[ -z "$VERSION" ]]; then
	echo "usage: $0 <X.Y.Z>  (or set CHUNK_YOUR_TOOLS_RELEASE_VERSION)" >&2
	exit 1
fi

release_tag="v${VERSION}"
go_tag="sdk/go/v${VERSION}"

if git ls-remote --exit-code origin "refs/tags/${go_tag}" >/dev/null 2>&1; then
	remote_sha="$(git ls-remote origin "refs/tags/${go_tag}" | awk '{print $1}')"
	release_sha="$(git rev-parse "refs/tags/${release_tag}^{commit}")"
	if [[ "${remote_sha}" != "${release_sha}" ]]; then
		echo "::warning::Tag ${go_tag} already exists on remote (${remote_sha:0:7}) but points to a different commit than ${release_tag} (${release_sha:0:7}); leaving it unchanged" >&2
	else
		echo "Tag ${go_tag} already exists on remote; skipping"
	fi
	exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
release_sha="$(git rev-parse "refs/tags/${release_tag}^{commit}")"
git tag "${go_tag}" "${release_sha}"
git push origin "refs/tags/${go_tag}"
echo "Created and pushed ${go_tag} at ${release_sha:0:7}"
