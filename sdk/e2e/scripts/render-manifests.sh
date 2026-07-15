#!/usr/bin/env bash
# Render gitignored manifests from .in templates using CYT_RELEASE_VERSION.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${CYT_RELEASE_VERSION:-}"

if [[ -z "$VERSION" ]]; then
	if [[ -n "${TAG:-}" ]]; then
		# shellcheck source=parse-version.sh
		eval "$("${ROOT}/scripts/parse-version.sh")"
	else
		echo "CYT_RELEASE_VERSION or TAG must be set" >&2
		exit 1
	fi
fi

render() {
	local src="$1"
	local dst="$2"
	sed "s/@CYT_RELEASE_VERSION@/${VERSION}/g" "$src" >"$dst"
	echo "rendered ${dst}"
}

render_rust_cargo() {
	local dst="${ROOT}/rust/Cargo.toml"
	if [[ "${CYT_E2E_USE_WORKSPACE:-}" == "1" ]]; then
		cat >"$dst" <<'EOF'
[workspace]

[package]
name = "chunk-your-tools-registry-e2e"
version = "0.0.0"
edition = "2021"
publish = false

[dependencies]
chunk-your-tools = { path = "../../../" }
serde_json = "1"
EOF
		echo "rendered ${dst} (workspace path=../../../)"
		return 0
	fi
	render "${ROOT}/rust/Cargo.toml.in" "$dst"
}

render_python_pyproject() {
	local dst="${ROOT}/python/pyproject.toml"
	if [[ "${CYT_E2E_USE_WORKSPACE:-}" == "1" ]]; then
		cat >"$dst" <<'EOF'
[project]
name = "chunk-your-tools-registry-e2e"
version = "0.0.0"
requires-python = ">=3.13,<4.0"
dependencies = ["chunk-your-tools"]

[dependency-groups]
test = ["pytest>=8.0"]

[tool.uv.sources]
chunk-your-tools = { path = "../../python", editable = true }

[tool.pytest.ini_options]
testpaths = ["tests"]
EOF
		echo "rendered ${dst} (workspace path=../../python)"
		return 0
	fi
	render "${ROOT}/python/pyproject.toml.in" "$dst"
}

render_typescript_package() {
	local dst="${ROOT}/typescript/package.json"
	if [[ "${CYT_E2E_USE_WORKSPACE:-}" == "1" ]]; then
		cat >"$dst" <<'EOF'
{
  "name": "chunk-your-tools-registry-e2e",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "node test/run.mjs"
  },
  "devDependencies": {
    "chunk-your-tools": "file:../../typescript"
  }
}
EOF
		echo "rendered ${dst} (workspace file:../../typescript)"
		return 0
	fi
	render "${ROOT}/typescript/package.json.in" "$dst"
}

render_go_mod() {
	local src="$1"
	local dst="$2"
	local staging="${CYT_E2E_STAGING:-${TMPDIR:-/tmp}/cyt-e2e-${VERSION}}"
	sed -e "s/@CYT_RELEASE_VERSION@/${VERSION}/g" \
		-e "s|@CYT_E2E_STAGING@|${staging}|g" \
		"$src" >"$dst"
	echo "rendered ${dst} (staging=${staging})"
}

render_rust_cargo
render_python_pyproject
render_typescript_package
render_go_mod "${ROOT}/go/go.mod.in" "${ROOT}/go/go.mod"
