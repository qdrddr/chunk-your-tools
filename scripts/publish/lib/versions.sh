# Shared SDK semver paths and verification for publish scripts.
# shellcheck shell=bash
#
# Source from scripts/publish/*.sh:
#   # shellcheck disable=SC1091
#   source "${SCRIPT_DIR}/lib/versions.sh"
#   publish_init_paths "${ROOT}"

publish_init_paths() {
	local root="${1:?repo root required}"
	PUBLISH_ROOT="${root}"
	PUBLISH_CARGO_TOML="${PUBLISH_ROOT}/Cargo.toml"
	PUBLISH_CARGO_LOCK="${PUBLISH_ROOT}/Cargo.lock"
	PUBLISH_SDK_PYPROJECT="${PUBLISH_ROOT}/sdk/python/pyproject.toml"
	PUBLISH_SDK_UV_LOCK="${PUBLISH_ROOT}/sdk/python/uv.lock"
	PUBLISH_PACKAGE_JSON="${PUBLISH_ROOT}/sdk/typescript/package.json"
	PUBLISH_PACKAGE_LOCK="${PUBLISH_ROOT}/sdk/typescript/package-lock.json"
	PUBLISH_C_CMAKE="${PUBLISH_ROOT}/sdk/c/CMakeLists.txt"
	PUBLISH_GO_VERSION="${PUBLISH_ROOT}/sdk/go/moduleversion/version.go"
	PUBLISH_TAG_FILE="${PUBLISH_ROOT}/search/.publish-tag"
}

publish_version_file_paths() {
	local file
	for file in \
		"${PUBLISH_CARGO_TOML}" \
		"${PUBLISH_CARGO_LOCK}" \
		"${PUBLISH_SDK_PYPROJECT}" \
		"${PUBLISH_SDK_UV_LOCK}" \
		"${PUBLISH_PACKAGE_JSON}" \
		"${PUBLISH_PACKAGE_LOCK}" \
		"${PUBLISH_C_CMAKE}" \
		"${PUBLISH_GO_VERSION}"; do
		printf '%s\n' "${file}"
	done
}

publish_validate_semver() {
	local version="$1"
	if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]; then
		printf 'error: invalid semver: %s\n' "${version}" >&2
		return 1
	fi
}

publish_read_cargo_version() {
	awk -F'"' '/^version = / { print $2; exit }' "${PUBLISH_CARGO_TOML}"
}

publish_read_pyproject_version() {
	grep -E '^version[[:space:]]*=' "${PUBLISH_SDK_PYPROJECT}" |
		head -1 |
		sed -E 's/^version[[:space:]]*=[[:space:]]*"(.*)".*/\1/'
}

publish_read_package_json_version() {
	grep -E '^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"' "${PUBLISH_PACKAGE_JSON}" |
		head -1 |
		sed -E 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"(.*)".*/\1/'
}

publish_read_cmake_project_version() {
	grep -E '^project\(chunk-your-tools-c VERSION ' "${PUBLISH_C_CMAKE}" |
		head -1 |
		sed -E 's/^project\(chunk-your-tools-c VERSION ([^ )]+).*/\1/'
}

publish_read_go_module_version() {
	grep -E '^const Version = "' "${PUBLISH_GO_VERSION}" |
		head -1 |
		sed -E 's/^const Version = "(.*)"/\1/'
}

publish_release_tag() {
	printf 'v%s\n' "$1"
}

publish_go_module_tag() {
	printf 'sdk/go/v%s\n' "$1"
}

publish_tag_file_path() {
	printf '%s\n' "${PUBLISH_TAG_FILE}"
}

publish_write_tag_file() {
	local tag="$1"
	printf 'tag=%s\n' "${tag}" >"${PUBLISH_TAG_FILE}"
}

publish_require_version_files() {
	local file
	for file in $(publish_version_file_paths); do
		if [[ ! -f "${file}" ]]; then
			if [[ "${file}" == "${PUBLISH_SDK_UV_LOCK}" ]]; then
				continue
			fi
			printf 'error: missing %s\n' "${file}" >&2
			return 1
		fi
	done
}

publish_verify_versions() {
	local expected="$1"
	local cargo py npm cmake go mismatches=0

	cargo="$(publish_read_cargo_version)"
	py="$(publish_read_pyproject_version)"
	npm="$(publish_read_package_json_version)"
	cmake="$(publish_read_cmake_project_version)"
	go="$(publish_read_go_module_version)"

	if [[ "${cargo}" != "${expected}" ]]; then
		printf 'error: Cargo.toml version %s != %s\n' "${cargo}" "${expected}" >&2
		mismatches=1
	fi
	if [[ "${py}" != "${expected}" ]]; then
		printf 'error: sdk/python/pyproject.toml version %s != %s\n' "${py}" "${expected}" >&2
		mismatches=1
	fi
	if [[ "${npm}" != "${expected}" ]]; then
		printf 'error: sdk/typescript/package.json version %s != %s\n' "${npm}" "${expected}" >&2
		mismatches=1
	fi
	if [[ "${cmake}" != "${expected}" ]]; then
		printf 'error: sdk/c/CMakeLists.txt VERSION %s != %s\n' "${cmake}" "${expected}" >&2
		mismatches=1
	fi
	if [[ "${go}" != "${expected}" ]]; then
		printf 'error: sdk/go/moduleversion/version.go Version %s != %s\n' "${go}" "${expected}" >&2
		mismatches=1
	fi

	[[ "${mismatches}" -eq 0 ]]
}
