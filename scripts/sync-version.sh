#!/usr/bin/env bash
# Propagate a single semver to all SDK package manifests and lockfiles.
#
# Usage:
#   ./scripts/sync-version.sh [VERSION]
#
# If VERSION is omitted, read it from Cargo.toml.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/shorten-paths.sh"
export SHORTEN_ROOT="${ROOT}"
CARGO_TOML="${ROOT}/Cargo.toml"
CARGO_LOCK="${ROOT}/Cargo.lock"
SDK_PYPROJECT="${ROOT}/sdk/python/pyproject.toml"
PACKAGE_JSON="${ROOT}/sdk/typescript/package.json"
PACKAGE_LOCK="${ROOT}/sdk/typescript/package-lock.json"
C_CMAKE="${ROOT}/sdk/c/CMakeLists.txt"
GO_VERSION="${ROOT}/sdk/go/moduleversion/version.go"
TAG_FILE="${ROOT}/search/.publish-tag"

usage() {
	cat <<EOF
Usage: $(basename "$0") [VERSION]

Propagate VERSION to all SDK manifests and lockfiles:
  - Cargo.toml
  - Cargo.lock (chunk-your-tools)
  - sdk/python/pyproject.toml
  - sdk/typescript/package.json
  - sdk/typescript/package-lock.json
  - sdk/c/CMakeLists.txt (project VERSION)
  - sdk/go/moduleversion/version.go (Version)

If VERSION is omitted, read it from ${CARGO_TOML}.
EOF
}

read_cargo_version() {
	awk -F'"' '/^version = / { print $2; exit }' "${CARGO_TOML}"
}

validate_version() {
	local version="$1"
	if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]; then
		echo "error: invalid semver: ${version}" >&2
		exit 1
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
	mv "${tmp}" "${file}"
}

update_cargo_lock_version() {
	local version="$1"
	local tmp
	tmp="$(mktemp)"
	awk -v version="${version}" '
    /^name = "chunk-your-tools"$/ { found=1 }
    found && /^version = / {
      print "version = \"" version "\""
      found=0
      next
    }
    { print }
  ' "${CARGO_LOCK}" >"${tmp}"
	mv "${tmp}" "${CARGO_LOCK}"
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
  ' "${PACKAGE_JSON}" >"${tmp}"
	mv "${tmp}" "${PACKAGE_JSON}"
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
  ' "${PACKAGE_LOCK}" >"${tmp}"
	mv "${tmp}" "${PACKAGE_LOCK}"
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
  ' "${C_CMAKE}" >"${tmp}"
	mv "${tmp}" "${C_CMAKE}"
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
  ' "${GO_VERSION}" >"${tmp}"
	mv "${tmp}" "${GO_VERSION}"
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
	version="$(read_cargo_version)"
	if [[ -z "${version}" ]]; then
		printf 'error: could not read version from %s\n' "${CARGO_TOML}" | shorten_paths >&2
		exit 1
	fi
fi

validate_version "${version}"

for file in \
	"${CARGO_TOML}" \
	"${CARGO_LOCK}" \
	"${SDK_PYPROJECT}" \
	"${PACKAGE_JSON}" \
	"${PACKAGE_LOCK}" \
	"${C_CMAKE}" \
	"${GO_VERSION}"; do
	if [[ ! -f "${file}" ]]; then
		printf 'error: missing %s\n' "${file}" | shorten_paths >&2
		exit 1
	fi
done

tag="v${version}"

update_toml_version "${CARGO_TOML}" "${version}"
update_cargo_lock_version "${version}"
update_toml_version "${SDK_PYPROJECT}" "${version}"
update_package_json_version "${version}"
update_package_lock_version "${version}"
update_cmake_project_version "${version}"
update_go_module_version "${version}"
printf 'tag=%s\n' "${tag}" >"${TAG_FILE}"

cat <<EOF | shorten_paths
synced version ${version} to:
  ${CARGO_TOML}
  ${CARGO_LOCK} (chunk-your-tools)
  ${SDK_PYPROJECT}
  ${PACKAGE_JSON}
  ${PACKAGE_LOCK}
  ${C_CMAKE} (project VERSION)
  ${GO_VERSION} (Version)
  ${TAG_FILE} (tag=${tag})
EOF
