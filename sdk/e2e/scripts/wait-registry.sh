#!/usr/bin/env bash
# Wait until a published package version is available on a registry.
# Usage: CHUNK_YOUR_TOOLS_RELEASE_VERSION=0.1.10 ./wait-registry.sh <crate|pypi-sdk|npm|tag|release-assets>
set -euo pipefail

TARGET="${1:-}"
VERSION="${CHUNK_YOUR_TOOLS_RELEASE_VERSION:-}"
if [[ -z "$TARGET" || -z "$VERSION" ]]; then
	echo "usage: CHUNK_YOUR_TOOLS_RELEASE_VERSION=x.y.z $0 <crate|pypi-sdk|npm|tag|release-assets>" >&2
	exit 1
fi

MAX_ATTEMPTS="${WAIT_REGISTRY_MAX_ATTEMPTS:-60}"
SLEEP_SECS="${WAIT_REGISTRY_SLEEP_SECS:-30}"

pypi_has_version() {
	local package="$1"
	local ver="$2"
	# Prefer uv resolution (same index as `uv sync`) when available.
	if command -v uv >/dev/null 2>&1; then
		uv pip install "${package}==${ver}" --dry-run -q >/dev/null 2>&1
		return
	fi
	PYPI_PACKAGE="$package" PYPI_VERSION="$ver" python3 -c "
import json
import os
import urllib.request

pkg = os.environ['PYPI_PACKAGE']
ver = os.environ['PYPI_VERSION']
url = f'https://pypi.org/pypi/{pkg}/json'
with urllib.request.urlopen(url, timeout=30) as resp:
    data = json.load(resp)
releases = data.get('releases', {})
if ver not in releases or not releases[ver]:
    raise SystemExit(1)
"
}

crate_has_version() {
	local ver="$1"
	local url="https://crates.io/api/v1/crates/chunk-your-tools/${ver}"
	# crates.io API requires a descriptive User-Agent (see https://crates.io/data-access)
	local ua="${CRATES_IO_USER_AGENT:-chunk-your-tools-e2e (https://github.com/qdrddr/chunk-your-tools)}"
	local code
	code="$(curl -sSL -o /dev/null -w "%{http_code}" -H "User-Agent: ${ua}" "$url")"
	[[ "$code" == "200" ]]
}

npm_has_version() {
	local ver="$1"
	npm view "chunk-your-tools@${ver}" version 2>/dev/null | grep -qxF "$ver"
}

tag_has_version() {
	local ver="$1"
	local tag="v${ver}"
	local repo="${CHUNK_YOUR_TOOLS_E2E_GIT_REPO:-https://github.com/qdrddr/chunk-your-tools.git}"
	git ls-remote --tags "$repo" "refs/tags/${tag}" | grep -q .
}

release_has_ffi_assets() {
	local ver="$1"
	local tag="v${ver}"
	local slug="${CHUNK_YOUR_TOOLS_E2E_GITHUB_REPO:-qdrddr/chunk-your-tools}"
	local url="https://api.github.com/repos/${slug}/releases/tags/${tag}"
	local json
	json="$(curl -fsSL "$url")"
	local expected=(
		chunk-your-tools-ffi-x86_64-unknown-linux-gnu.tar.gz
		chunk-your-tools-ffi-aarch64-unknown-linux-gnu.tar.gz
		chunk-your-tools-ffi-x86_64-apple-darwin.tar.gz
		chunk-your-tools-ffi-aarch64-apple-darwin.tar.gz
		chunk-your-tools-ffi-x86_64-pc-windows-msvc.tar.gz
		chunk-your-tools-ffi-aarch64-pc-windows-msvc.tar.gz
		SHA256SUMS
		chunk_your_tools.h
	)
	local name
	for name in "${expected[@]}"; do
		if ! printf '%s' "$json" | grep -q "\"name\": \"${name}\""; then
			return 1
		fi
	done
}

wait_loop() {
	local label="$1"
	shift
	local attempt=1
	while [[ "$attempt" -le "$MAX_ATTEMPTS" ]]; do
		if "$@"; then
			echo "${label} ${VERSION} is available (attempt ${attempt})"
			return 0
		fi
		echo "Waiting for ${label} ${VERSION}... (${attempt}/${MAX_ATTEMPTS})"
		sleep "$SLEEP_SECS"
		attempt=$((attempt + 1))
	done
	echo "::error::Timed out waiting for ${label} ${VERSION}" >&2
	return 1
}

case "$TARGET" in
crate)
	wait_loop "crates.io/chunk-your-tools" crate_has_version "$VERSION"
	;;
pypi-sdk)
	wait_loop "PyPI/chunk-your-tools" pypi_has_version "chunk-your-tools" "$VERSION"
	;;
npm)
	wait_loop "npm/chunk-your-tools" npm_has_version "$VERSION"
	;;
tag)
	wait_loop "GitHub/chunk-your-tools" tag_has_version "$VERSION"
	;;
release-assets)
	wait_loop "GitHub Release C FFI assets" release_has_ffi_assets "$VERSION"
	;;
*)
	echo "unknown target: ${TARGET}" >&2
	exit 1
	;;
esac
