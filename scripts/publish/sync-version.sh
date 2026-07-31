#!/usr/bin/env bash
# Propagate a single semver to all SDK package manifests and lockfiles.
#
# Usage:
#   ./scripts/publish/sync-version.sh [VERSION]
#
# If VERSION is omitted, read it from Cargo.toml.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/shorten-paths.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/versions.sh"

export SHORTEN_ROOT="${ROOT}"
publish_init_paths "${ROOT}"

usage() {
	cat <<EOF
Usage: $(basename "$0") [VERSION]

Propagate VERSION to all SDK manifests and lockfiles:
  - Cargo.toml
  - Cargo.lock (chunk-your-tools)
  - sdk/python/pyproject.toml
  - sdk/python/uv.lock (editable package version)
  - sdk/typescript/package.json
  - sdk/typescript/package-lock.json
  - sdk/c/CMakeLists.txt (project VERSION)
  - sdk/go/moduleversion/version.go (Version)

If VERSION is omitted, read it from ${PUBLISH_CARGO_TOML}.

Also used by pre-commit (sync-version hook) and scripts/publish/publish-git.sh.
EOF
}

write_if_changed() {
	local file="$1"
	local tmp="$2"
	if cmp -s "${tmp}" "${file}"; then
		rm -f "${tmp}"
	else
		mv "${tmp}" "${file}"
	fi
}

update_toml_version() {
	local file="$1"
	local version="$2"
	local tmp
	tmp="$(mktemp)"
	awk -v version="${version}" '
    !done && /^version[[:space:]]*=/ {
      print "version = \"" version "\""
      done=1
      next
    }
    { print }
  ' "${file}" >"${tmp}"
	write_if_changed "${file}" "${tmp}"
}

update_cargo_lock_version() {
	local version="$1"
	local tmp
	tmp="$(mktemp)"
	# Only update the real [[package]] entry. [[patch.unused]] blocks come from
	# parent .cargo/config.toml [patch.crates-io] and are rewritten by cargo/maturin.
	awk -v version="${version}" '
    /^\[\[package\]\]$/ { block="package"; found=0; print; next }
    /^\[\[patch\.unused\]\]$/ { block="patch"; found=0; print; next }
    block == "package" && /^name = "chunk-your-tools"$/ { found=1; print; next }
    found && /^version = / {
      print "version = \"" version "\""
      found=0
      next
    }
    { print }
  ' "${PUBLISH_CARGO_LOCK}" >"${tmp}"
	write_if_changed "${PUBLISH_CARGO_LOCK}" "${tmp}"
}

update_package_json_version() {
	local version="$1"
	local tmp
	tmp="$(mktemp)"
	awk -v version="${version}" '
    !done && /^  "version": "/ {
      print "  \"version\": \"" version "\","
      done=1
      next
    }
    { print }
  ' "${PUBLISH_PACKAGE_JSON}" >"${tmp}"
	write_if_changed "${PUBLISH_PACKAGE_JSON}" "${tmp}"
}

update_package_lock_version() {
	local version="$1"
	local tmp
	tmp="$(mktemp)"
	awk -v version="${version}" '
    BEGIN { root_done=0; pkg_done=0 }
    !root_done && /^  "version": "/ {
      print "  \"version\": \"" version "\","
      root_done=1
      next
    }
    !pkg_done && /^      "version": "/ {
      print "      \"version\": \"" version "\","
      pkg_done=1
      next
    }
    { print }
  ' "${PUBLISH_PACKAGE_LOCK}" >"${tmp}"
	write_if_changed "${PUBLISH_PACKAGE_LOCK}" "${tmp}"
}

update_cmake_project_version() {
	local version="$1"
	local tmp
	tmp="$(mktemp)"
	awk -v version="${version}" '
    /^project\(chunk-your-tools-c VERSION / {
      print "project(chunk-your-tools-c VERSION " version " LANGUAGES C)"
      next
    }
    { print }
  ' "${PUBLISH_C_CMAKE}" >"${tmp}"
	write_if_changed "${PUBLISH_C_CMAKE}" "${tmp}"
}

update_go_module_version() {
	local version="$1"
	local tmp
	tmp="$(mktemp)"
	awk -v version="${version}" '
    /^const Version = "/ {
      print "const Version = \"" version "\""
      next
    }
    { print }
  ' "${PUBLISH_GO_VERSION}" >"${tmp}"
	write_if_changed "${PUBLISH_GO_VERSION}" "${tmp}"
}

update_uv_lock() {
	local py_dir="${PUBLISH_ROOT}/sdk/python"
	[[ -f "${py_dir}/uv.lock" ]] || return 0
	if ! command -v uv >/dev/null 2>&1; then
		printf 'error: uv is required to refresh sdk/python/uv.lock after a version bump\n' | shorten_paths >&2
		exit 1
	fi
	(
		cd "${py_dir}"
		uv lock
	)
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

if [[ $# -gt 1 ]]; then
	usage >&2
	exit 1
fi

if [[ $# -eq 1 ]]; then
	version="$1"
else
	version="$(publish_read_cargo_version)"
	if [[ -z "${version}" ]]; then
		printf 'error: could not read version from %s\n' "${PUBLISH_CARGO_TOML}" | shorten_paths >&2
		exit 1
	fi
fi

publish_validate_semver "${version}"
publish_require_version_files

tag="$(publish_release_tag "${version}")"

update_toml_version "${PUBLISH_CARGO_TOML}" "${version}"
update_cargo_lock_version "${version}"
update_toml_version "${PUBLISH_SDK_PYPROJECT}" "${version}"
update_uv_lock
update_package_json_version "${version}"
update_package_lock_version "${version}"
update_cmake_project_version "${version}"
update_go_module_version "${version}"
printf 'tag=%s\n' "${tag}" >"$(publish_tag_file_path)"

publish_verify_versions "${version}"

cat <<EOF | shorten_paths
synced version ${version} to:
  ${PUBLISH_CARGO_TOML}
  ${PUBLISH_CARGO_LOCK} (chunk-your-tools)
  ${PUBLISH_SDK_PYPROJECT}
  ${PUBLISH_ROOT}/sdk/python/uv.lock
  ${PUBLISH_PACKAGE_JSON}
  ${PUBLISH_PACKAGE_LOCK}
  ${PUBLISH_C_CMAKE} (project VERSION)
  ${PUBLISH_GO_VERSION} (Version)
  $(publish_tag_file_path) (tag=${tag})
EOF
