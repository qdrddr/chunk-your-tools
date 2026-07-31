#!/usr/bin/env bash
# Verify dependency pins and lockfile freshness across monorepo ecosystems.
#
# Usage:
#   ./scripts/deps/verify-pins.sh
#   ./scripts/deps/verify-pins.sh --short
#   ./scripts/deps/verify-pins.sh --manifest-lint
#   ./scripts/deps/verify-pins.sh --skip rust --skip npm
#   ./scripts/deps/verify-pins.sh --output-dir /tmp/pin-audit
#
# Writes reports under scripts/deps/output/audit-YYYYMMDD-HHMMSS/ by default.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/shorten-paths.sh"
export SHORTEN_ROOT="${REPO_ROOT}"

DO_MANIFEST_LINT=0
DO_REPORT=1
REPORT_EXPLICIT=0
OUTPUT_DIR=""
SHORT=0
SKIP_PYTHON=0
SKIP_RUST=0
SKIP_NPM=0
SKIP_GO=0
SKIP_C=0

DEPS_OUTPUT_DIR=""
DEPS_SUMMARY_FILE=""
MANIFEST_LINT_FILE=""
FAILURES=0

die() {
	printf 'error: %s\n' "$*" | shorten_paths >&2
	exit 1
}

info() {
	if [[ "${SHORT}" -eq 1 ]]; then
		return 0
	fi
	printf '==> %s\n' "$*" | shorten_paths
}

filter_short_output() {
	awk '
		/^==>/ { next }
		/^ok:/ { next }
		/^$/ { next }
		/^FAIL:/ { print; next }
		/^error:/ { print; next }
		/^[Ww]arning:/ { print; next }
		/loose (Python specifier|npm range|Cargo)/ { print; next }
		/exact version pin/ { print; next }
		/cargo metadata --locked/ { print; next }
		/cargo\.toml\/Cargo\.lock policy/ { print; next }
		/[Mm]ismatch/ { print; next }
		/out of sync/ { print; next }
		/missing / { print; next }
		/check\(s\) failed/ { print; next }
		/[Ee]rror/ { print; next }
		/[Ww]arn(ing)?:/ { print; next }
		/FAILED/ { print; next }
		/npm ERR!/ { print; next }
	'
}

emit_cmd_output() {
	if [[ "${SHORT}" -eq 1 ]]; then
		shorten_paths | filter_short_output >&2
	else
		shorten_paths >&2
	fi
}

run_cmd() {
	if command -v rtk >/dev/null 2>&1; then
		rtk "$@"
	else
		"$@"
	fi
}

run_cmd_quiet() {
	run_cmd "$@" >/dev/null 2>&1
}

slug() {
	local value="${1:-unknown}"
	value="${value//\//-}"
	value="${value#-}"
	value="${value:-root}"
	printf '%s' "${value}"
}

init_output_dir() {
	local requested="${1:-}"
	if [[ -n "${requested}" ]]; then
		DEPS_OUTPUT_DIR="${requested}"
	else
		DEPS_OUTPUT_DIR="${SCRIPT_DIR}/output/audit-$(date +%Y%m%d-%H%M%S)"
	fi
	mkdir -p "${DEPS_OUTPUT_DIR}"
	export DEPS_OUTPUT_DIR
	DEPS_SUMMARY_FILE="${DEPS_OUTPUT_DIR}/summary.txt"
	MANIFEST_LINT_FILE="${DEPS_OUTPUT_DIR}/manifest-lint.txt"
	: >"${DEPS_SUMMARY_FILE}"
	: >"${MANIFEST_LINT_FILE}"
	write_summary_line "dependency pin audit summary"
	write_summary_line "repo: ${REPO_ROOT}"
	write_summary_line "output: ${DEPS_OUTPUT_DIR}"
	write_summary_line "started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
	write_summary_line ""
	if [[ "${SHORT}" -eq 0 ]]; then
		info "writing reports to ${DEPS_OUTPUT_DIR}"
	fi
}

write_summary_line() {
	local line="$1"
	if [[ -n "${DEPS_SUMMARY_FILE}" ]]; then
		printf '%s\n' "${line}" >>"${DEPS_SUMMARY_FILE}"
	fi
}

report_path() {
	printf '%s/%s' "${DEPS_OUTPUT_DIR}" "$1"
}

append_manifest_lint() {
	local line="$1"
	if [[ -n "${MANIFEST_LINT_FILE}" ]]; then
		printf '%s\n' "${line}" >>"${MANIFEST_LINT_FILE}"
	fi
	printf '%s\n' "${line}" | shorten_paths >&2
}

require_repo_root() {
	[[ -f "${REPO_ROOT}/Cargo.toml" ]] ||
		die "not a repo root: ${REPO_ROOT} (expected Cargo.toml)"
	[[ -f "${REPO_ROOT}/sdk/python/pyproject.toml" ]] ||
		die "not a repo root: ${REPO_ROOT} (expected sdk/python/pyproject.toml)"
	[[ -f "${REPO_ROOT}/sdk/c/CMakeLists.txt" ]] ||
		die "not a repo root: ${REPO_ROOT} (expected sdk/c/CMakeLists.txt)"
}

read_cargo_version() {
	grep -E '^version[[:space:]]*=' "${REPO_ROOT}/Cargo.toml" |
		head -1 |
		sed -E 's/^version[[:space:]]*=[[:space:]]*"(.*)".*/\1/'
}

read_cmake_project_version() {
	grep -E '^project\(chunk-your-tools-c VERSION ' "${REPO_ROOT}/sdk/c/CMakeLists.txt" |
		head -1 |
		sed -E 's/^project\(chunk-your-tools-c VERSION ([^ ]+) .*/\1/'
}

record_failure() {
	local name="$1"
	local detail="$2"
	printf 'FAIL: %s: %s\n' "${name}" "${detail}" | shorten_paths >&2
	write_summary_line "${name}: failed (${detail})"
	FAILURES=$((FAILURES + 1))
}

record_ok() {
	local name="$1"
	if [[ "${SHORT}" -eq 1 ]]; then
		write_summary_line "${name}: ok"
		return 0
	fi
	printf 'ok: %s\n' "${name}" | shorten_paths
	write_summary_line "${name}: ok"
}

run_step() {
	local name="$1"
	shift
	if [[ "${SHORT}" -eq 0 ]]; then
		info "=== ${name} ==="
	fi
	if "$@"; then
		record_ok "${name}"
	else
		local status=$?
		if [[ "${SHORT}" -eq 1 ]]; then
			info "=== ${name} ==="
		fi
		record_failure "${name}" "exit ${status}"
	fi
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--output-dir)
		[[ $# -ge 2 ]] || die "--output-dir requires a path"
		OUTPUT_DIR="$2"
		shift 2
		;;
	--output-dir=*)
		OUTPUT_DIR="${1#*=}"
		shift
		;;
	--no-report)
		DO_REPORT=0
		REPORT_EXPLICIT=1
		shift
		;;
	--short)
		SHORT=1
		shift
		;;
	--report)
		DO_REPORT=1
		REPORT_EXPLICIT=1
		shift
		;;
	--no-manifest-lint)
		DO_MANIFEST_LINT=0
		shift
		;;
	--manifest-lint)
		DO_MANIFEST_LINT=1
		shift
		;;
	--skip)
		[[ $# -ge 2 ]] || die "--skip requires python|rust|npm|go|c"
		case "$2" in
		python) SKIP_PYTHON=1 ;;
		rust) SKIP_RUST=1 ;;
		npm) SKIP_NPM=1 ;;
		go) SKIP_GO=1 ;;
		c) SKIP_C=1 ;;
		*) die "unknown --skip target: $2 (expected python|rust|npm|go|c)" ;;
		esac
		shift 2
		;;
	--skip=*)
		case "${1#*=}" in
		python) SKIP_PYTHON=1 ;;
		rust) SKIP_RUST=1 ;;
		npm) SKIP_NPM=1 ;;
		go) SKIP_GO=1 ;;
		c) SKIP_C=1 ;;
		*) die "unknown --skip target: ${1#*=}" ;;
		esac
		shift
		;;
	-h | --help)
		cat <<'EOF'
Usage: verify-pins.sh [options]

Verify lockfiles are in sync with manifests. With --manifest-lint, also verify
SDK version fields stay aligned across Cargo.toml, pyproject.toml, package.json,
CMakeLists.txt, and Go moduleversion (dependency ranges may stay loose when a
lockfile pins them).

Writes pinned-version inventory and check results under:
  scripts/deps/output/audit-YYYYMMDD-HHMMSS/

Checked targets:
  sdk/python     uv.lock
  Cargo.toml     Cargo.lock (workspace root; lock step verifies all manifest deps
                 are locked; manifests must not use exact = pins)
  sdk/c          CMakeLists.txt VERSION + synced chunk_your_tools.h
  sdk/go         go.sum
  package.json   package-lock.json (root + sdk/typescript)

Options:
  --output-dir DIR      Directory for generated reports (default: timestamped)
  --report              Write audit reports (default)
  --no-report           Skip report files; console output only
  --short               Lock checks only; on success print one line (use with --report for audit files)
  --manifest-lint       Verify SDK version sync (+ loose ranges when lockfiles missing;
                        Cargo.toml ranges are not linted — use rust lock step)
  --no-manifest-lint    Skip manifest checks; lockfiles only (default)
  --skip TARGET         Skip python, rust, npm, go, or c (repeatable)

Examples:
  ./scripts/deps/verify-pins.sh
  ./scripts/deps/verify-pins.sh --short
  ./scripts/deps/verify-pins.sh --no-manifest-lint
  ./scripts/deps/verify-pins.sh --output-dir /tmp/pin-audit
  ./scripts/deps/verify-pins.sh --skip go
EOF
		exit 0
		;;
	*)
		die "unknown arg: $1 (try --help)"
		;;
	esac
done

if [[ "${SHORT}" -eq 1 && "${REPORT_EXPLICIT}" -eq 0 ]]; then
	DO_REPORT=0
fi

require_repo_root
[[ "${DO_REPORT}" -eq 1 ]] && init_output_dir "${OUTPUT_DIR}"

run_checked() {
	local out_file="$1"
	shift
	local tmp="" capture=0

	if [[ "${DO_REPORT}" -eq 1 ]]; then
		tmp="${out_file}"
		capture=1
	elif [[ "${SHORT}" -eq 1 ]]; then
		tmp="$(mktemp)"
		capture=1
	fi

	if [[ "${capture}" -eq 1 ]]; then
		if "$@" >"${tmp}" 2>&1; then
			[[ "${DO_REPORT}" -eq 0 ]] && rm -f "${tmp}"
			return 0
		fi
		<"${tmp}" emit_cmd_output
		[[ "${DO_REPORT}" -eq 0 ]] && rm -f "${tmp}"
		return 1
	fi

	run_cmd "$@" 2>&1 | shorten_paths >&2
	return "${PIPESTATUS[0]}"
}

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

run_in_dir() {
	local dir="$1"
	shift
	(cd "${dir}" && run_cmd "$@")
}

report_python_inventory() {
	local label="$1"
	local project_dir="$2"
	local slug_name out_req out_pylock

	require_cmd uv
	slug_name="$(slug "${label}")"
	out_req="$(report_path "python-${slug_name}-requirements.txt")"
	out_pylock="$(report_path "pylock.${slug_name}.toml")"

	info "python ${label}: export pinned versions"
	(
		cd "${project_dir}"
		run_cmd_quiet uv export --frozen --all-extras --group dev \
			--format requirements.txt --output-file "${out_req}"
		run_cmd_quiet uv export --frozen --all-extras --group dev \
			--format pylock.toml --output-file "${out_pylock}"
	)
	write_summary_line "python ${label}: inventory -> python-${slug_name}-requirements.txt, pylock.${slug_name}.toml"
}

verify_python_lock() {
	local label="$1"
	local project_dir="$2"
	local slug_name out_check

	require_cmd uv
	[[ -f "${project_dir}/pyproject.toml" ]] ||
		die "python ${label}: missing pyproject.toml"
	[[ -f "${project_dir}/uv.lock" ]] ||
		die "python ${label}: missing uv.lock (run: uv lock --project ${project_dir})"

	slug_name="$(slug "${label}")"
	out_check=""
	[[ "${DO_REPORT}" -eq 1 ]] && out_check="$(report_path "python-${slug_name}-lock-check.txt")"

	info "python ${label}: uv lock --check"
	if run_checked "${out_check}" run_in_dir "${project_dir}" uv lock --check; then
		[[ "${DO_REPORT}" -eq 1 ]] &&
			write_summary_line "python ${label}: lock check -> python-${slug_name}-lock-check.txt"
		[[ "${DO_REPORT}" -eq 1 ]] && report_python_inventory "${label}" "${project_dir}"
		return 0
	fi
	return 1
}

report_rust_inventory() {
	local label="$1"
	local crate_dir="$2"
	local slug_name out_json out_tree

	require_cmd cargo
	slug_name="$(slug "${label}")"
	out_json="$(report_path "rust-${slug_name}-packages.json")"
	out_tree="$(report_path "rust-${slug_name}-tree.txt")"

	info "rust ${label}: export pinned packages"
	(
		cd "${crate_dir}"
		run_cmd_quiet cargo metadata --locked --format-version 1 --quiet \
			>"${out_json}.raw" 2>/dev/null
		if command -v jq >/dev/null 2>&1; then
			jq '[.packages[] | {name, version, source}] | sort_by(.name)' \
				"${out_json}.raw" >"${out_json}"
			rm -f "${out_json}.raw"
		else
			mv "${out_json}.raw" "${out_json}"
		fi
		run_cmd_quiet cargo tree --locked --prefix none >"${out_tree}" 2>/dev/null || true
	)
	write_summary_line "rust ${label}: inventory -> rust-${slug_name}-packages.json, rust-${slug_name}-tree.txt"
}

read_cargo_toml_dep_names() {
	local toml="$1"
	awk '
		/^\[(dependencies|dev-dependencies|build-dependencies)\]/ { in_deps=1; next }
		/^\[/ { in_deps=0; next }
		in_deps && /^[a-zA-Z0-9_-]+[[:space:]]*=/ {
			line=$0
			name=$1
			sub(/=.*/, "", name)
			if (line ~ /path[[:space:]]*=/) next
			if (line ~ /git[[:space:]]*=/) next
			if (line ~ /workspace[[:space:]]*=/) next
			print name
		}
	' "${toml}" | sort -u
}

cargo_lock_has_package() {
	local lock_file="$1"
	local dep_name="$2"
	awk -v want="${dep_name}" '
		/^name = / {
			gsub(/"/, "", $3)
			if ($3 == want) {
				found=1
			}
		}
		END { exit found ? 0 : 1 }
	' "${lock_file}"
}

verify_cargo_manifest_lock_policy() {
	local crate_dir="$1"
	local label="$2"
	local toml="${crate_dir}/Cargo.toml"
	local lock="${crate_dir}/Cargo.lock"
	local issues=0
	local dep content lineno

	while IFS= read -r content; do
		lineno="${content%%:*}"
		content="${content#*:}"
		if [[ "${content}" =~ version[[:space:]]*=[[:space:]]*\"= ]] ||
			[[ "${content}" =~ ^[[:space:]]*[a-zA-Z0-9_-]+[[:space:]]*=[[:space:]]*\"= ]]; then
			printf '%s:%s: exact version pin in Cargo.toml (use semver ranges; pin in Cargo.lock)\n' \
				"${toml}" "${lineno}"
			issues=$((issues + 1))
		fi
	done < <(
		awk '
			/^\[(dependencies|dev-dependencies|build-dependencies)\]/ { in_deps=1; next }
			/^\[/ { in_deps=0; next }
			in_deps { print NR ":" $0 }
		' "${toml}"
	)

	while IFS= read -r dep; do
		[[ -n "${dep}" ]] || continue
		if ! cargo_lock_has_package "${lock}" "${dep}"; then
			printf '%s: dependency %s declared in Cargo.toml but missing from Cargo.lock\n' \
				"${label}" "${dep}"
			issues=$((issues + 1))
		fi
	done < <(read_cargo_toml_dep_names "${toml}")

	if [[ "${issues}" -gt 0 ]]; then
		return 1
	fi
	printf 'cargo.toml/Cargo.lock policy: all manifest deps locked; no exact pins in manifest\n'
	return 0
}

run_rust_lock_checks() {
	local crate_dir="$1"
	local label="$2"
	local failed=0
	local meta_log

	meta_log="$(mktemp)"
	if ! run_in_dir "${crate_dir}" cargo metadata --locked --format-version 1 --quiet \
		>"${meta_log}" 2>&1; then
		printf 'cargo metadata --locked: failed (lockfile out of sync with Cargo.toml)\n'
		sed -n '1,5p' "${meta_log}"
		failed=1
	else
		printf 'cargo metadata --locked: ok\n'
	fi
	rm -f "${meta_log}"

	if ! verify_cargo_manifest_lock_policy "${crate_dir}" "${label}"; then
		failed=1
	fi

	return "${failed}"
}

verify_rust_lock() {
	local label="$1"
	local crate_dir="$2"
	local slug_name out_check

	require_cmd cargo
	[[ -f "${crate_dir}/Cargo.toml" ]] ||
		die "rust ${label}: missing Cargo.toml"
	[[ -f "${crate_dir}/Cargo.lock" ]] ||
		die "rust ${label}: missing Cargo.lock (run: cargo generate-lockfile in ${crate_dir})"

	slug_name="$(slug "${label}")"
	out_check=""
	[[ "${DO_REPORT}" -eq 1 ]] && out_check="$(report_path "rust-${slug_name}-lock-check.txt")"

	info "rust ${label}: cargo lock sync and manifest policy"
	if run_checked "${out_check}" run_rust_lock_checks "${crate_dir}" "${label}"; then
		[[ "${DO_REPORT}" -eq 1 ]] &&
			write_summary_line "rust ${label}: lock check -> rust-${slug_name}-lock-check.txt"
		[[ "${DO_REPORT}" -eq 1 ]] && report_rust_inventory "${label}" "${crate_dir}"
		return 0
	fi
	return 1
}

report_go_inventory() {
	local mod_dir="${REPO_ROOT}/sdk/go"
	local out_mods out_sum

	out_mods="$(report_path "go-modules.txt")"
	out_sum="$(report_path "go-sum.txt")"

	info "go: export pinned modules"
	(
		cd "${mod_dir}"
		run_cmd_quiet go list -m all | sort >"${out_mods}"
		cp go.sum "${out_sum}"
	)
	write_summary_line "go: inventory -> go-modules.txt, go-sum.txt"
}

verify_go_lock() {
	local mod_dir="${REPO_ROOT}/sdk/go"
	local out_check

	require_cmd go
	[[ -f "${mod_dir}/go.mod" ]] ||
		die "go: missing go.mod"
	[[ -f "${mod_dir}/go.sum" ]] ||
		die "go: missing go.sum (run: go mod tidy in sdk/go)"

	out_check=""
	[[ "${DO_REPORT}" -eq 1 ]] && out_check="$(report_path "go-lock-check.txt")"

	info "go: go mod verify"
	if run_checked "${out_check}" run_in_dir "${mod_dir}" go mod verify; then
		[[ "${DO_REPORT}" -eq 1 ]] &&
			write_summary_line "go: lock check -> go-lock-check.txt"
		[[ "${DO_REPORT}" -eq 1 ]] && report_go_inventory
		return 0
	fi
	return 1
}

report_c_inventory() {
	local c_dir="${REPO_ROOT}/sdk/c"
	local out_manifest out_version
	local cargo_version cmake_version cmake_min

	out_manifest="$(report_path "c-sdk-manifest.txt")"
	out_version="$(report_path "c-sdk-version.txt")"
	cargo_version="$(read_cargo_version)"
	cmake_version="$(read_cmake_project_version)"
	cmake_min="$(grep -E '^cmake_minimum_required\(VERSION ' "${c_dir}/CMakeLists.txt" |
		head -1 |
		sed -E 's/^cmake_minimum_required\(VERSION ([^)]+)\).*/\1/')"

	info "c sdk: export manifest inventory"
	{
		printf 'workspace_version=%s\n' "${cargo_version}"
		printf 'cmake_project_version=%s\n' "${cmake_version}"
		printf 'cmake_minimum_required=%s\n' "${cmake_min}"
		printf 'dependency_lockfile=Cargo.lock\n'
		printf 'build_script=sdk/c/scripts/build-c-lib.sh\n'
		printf 'public_header=sdk/c/include/chunk_your_tools.h\n'
		printf 'supported_targets=\n'
		awk '
			/^_chunk_your_tools_supported_targets/ { in_list=1; next }
			in_list && /^[[:space:]]*[a-z0-9_]+-/ { gsub(/^[[:space:]]+/, ""); print "  " $0 }
			in_list && /^\)/ { in_list=0 }
		' "${c_dir}/CMakeLists.txt"
	} >"${out_version}"
	cp "${c_dir}/CMakeLists.txt" "${out_manifest}"
	write_summary_line "c sdk: inventory -> c-sdk-version.txt, c-sdk-manifest.txt"
}

verify_c_sdk() {
	local c_dir="${REPO_ROOT}/sdk/c"
	local cmake_file="${c_dir}/CMakeLists.txt"
	local build_script="${c_dir}/scripts/build-c-lib.sh"
	local header_src="${REPO_ROOT}/chunk_your_tools.h"
	local header_dest="${c_dir}/include/chunk_your_tools.h"
	local cargo_version cmake_version out_check slug_name

	slug_name="$(slug "sdk-c")"
	out_check=""
	[[ "${DO_REPORT}" -eq 1 ]] && out_check="$(report_path "c-${slug_name}-check.txt")"

	[[ -f "${cmake_file}" ]] ||
		die "c sdk: missing CMakeLists.txt"
	[[ -f "${build_script}" ]] ||
		die "c sdk: missing scripts/build-c-lib.sh"
	[[ -x "${build_script}" ]] ||
		die "c sdk: build script not executable: ${build_script}"
	[[ -f "${header_dest}" ]] ||
		die "c sdk: missing include/chunk_your_tools.h"
	[[ -f "${header_src}" ]] ||
		die "c sdk: missing root chunk_your_tools.h (run: cargo build -p chunk-your-tools --features ffi)"

	cargo_version="$(read_cargo_version)"
	cmake_version="$(read_cmake_project_version)"
	[[ -n "${cargo_version}" ]] ||
		die "c sdk: could not read Cargo.toml version"
	[[ -n "${cmake_version}" ]] ||
		die "c sdk: could not read CMake project VERSION"

	info "c sdk: verify version sync and header"
	if [[ "${DO_REPORT}" -eq 1 ]]; then
		if ! {
			echo "cargo_version=${cargo_version}"
			echo "cmake_version=${cmake_version}"
			[[ "${cargo_version}" == "${cmake_version}" ]] ||
				{
					echo "version mismatch: sync with ./scripts/publish/sync-version.sh"
					exit 1
				}
			cmp -s "${header_src}" "${header_dest}" ||
				{
					echo "header out of sync: run bash sdk/c/scripts/build-c-lib.sh --sync-header"
					exit 1
				}
			echo "header synced"
			echo "ffi dependency lockfile: Cargo.lock (checked via rust lock step)"
		} >"${out_check}" 2>&1; then
			<"${out_check}" emit_cmd_output
			return 1
		fi
	else
		[[ "${cargo_version}" == "${cmake_version}" ]] ||
			{
				printf 'c sdk: version mismatch: Cargo.toml=%s CMakeLists.txt=%s\n' \
					"${cargo_version}" "${cmake_version}" | shorten_paths >&2
				return 1
			}
		cmp -s "${header_src}" "${header_dest}" ||
			{
				printf '%s\n' \
					"c sdk: header out of sync (run: bash sdk/c/scripts/build-c-lib.sh --sync-header)" |
					shorten_paths >&2
				return 1
			}
	fi

	[[ "${DO_REPORT}" -eq 1 ]] &&
		write_summary_line "c sdk: check -> c-${slug_name}-check.txt"
	[[ "${DO_REPORT}" -eq 1 ]] && report_c_inventory
	return 0
}

report_npm_inventory() {
	local label="$1"
	local package_dir="$2"
	local slug_name out_json out_direct

	slug_name="$(slug "${label}")"
	out_json="$(report_path "npm-${slug_name}-packages.json")"
	out_direct="$(report_path "npm-${slug_name}-direct.json")"

	info "npm ${label}: export pinned packages"
	if command -v jq >/dev/null 2>&1; then
		jq -S '
			{
				root: .packages[""].version,
				packages: [
					.packages
					| to_entries[]
					| select(.key != "" and (.value.version? // null) != null)
					| {
						name: (.value.name // (.key | sub("^node_modules/"; ""))),
						version: .value.version,
						development: (.value.dev // false)
					}
				]
				| unique
				| sort_by(.name)
			}
		' "${package_dir}/package-lock.json" >"${out_json}"
		jq -S '
			{
				dependencies: (.packages[""].dependencies // {}),
				devDependencies: (.packages[""].devDependencies // {})
			}
		' "${package_dir}/package-lock.json" >"${out_direct}"
	else
		cp "${package_dir}/package-lock.json" "${out_json}"
	fi
	write_summary_line "npm ${label}: inventory -> npm-${slug_name}-packages.json, npm-${slug_name}-direct.json"
}

verify_npm_lock() {
	local label="$1"
	local package_dir="$2"
	local slug_name out_check

	require_cmd npm
	[[ -f "${package_dir}/package.json" ]] ||
		die "npm ${label}: missing package.json"
	[[ -f "${package_dir}/package-lock.json" ]] ||
		die "npm ${label}: missing package-lock.json (run: npm install in ${package_dir})"

	slug_name="$(slug "${label}")"
	out_check=""
	[[ "${DO_REPORT}" -eq 1 ]] && out_check="$(report_path "npm-${slug_name}-lock-check.txt")"

	info "npm ${label}: npm ci --dry-run"
	if run_checked "${out_check}" run_in_dir "${package_dir}" \
		env -u npm_config_devdir -u NODE_ENV npm ci --dry-run --ignore-scripts; then
		[[ "${DO_REPORT}" -eq 1 ]] &&
			write_summary_line "npm ${label}: lock check -> npm-${slug_name}-lock-check.txt"
		[[ "${DO_REPORT}" -eq 1 ]] && report_npm_inventory "${label}" "${package_dir}"
		return 0
	fi
	return 1
}

read_pyproject_version() {
	local file="$1"
	grep -E '^version[[:space:]]*=' "${file}" |
		head -1 |
		sed -E 's/^version[[:space:]]*=[[:space:]]*"(.*)".*/\1/'
}

read_package_json_version() {
	local file="$1"
	grep -E '^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"' "${file}" |
		head -1 |
		sed -E 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"(.*)".*/\1/'
}

read_go_module_version() {
	local file="$1"
	grep -E '^const Version = "' "${file}" |
		head -1 |
		sed -E 's/^const Version = "(.*)"/\1/'
}

lint_sdk_version_sync() {
	local cargo_version py_version npm_version go_version cmake_version

	cargo_version="$(read_cargo_version)"
	py_version="$(read_pyproject_version "${REPO_ROOT}/sdk/python/pyproject.toml")"
	npm_version="$(read_package_json_version "${REPO_ROOT}/sdk/typescript/package.json")"
	go_version="$(read_go_module_version "${REPO_ROOT}/sdk/go/moduleversion/version.go")"
	cmake_version="$(read_cmake_project_version)"

	[[ -n "${cargo_version}" ]] ||
		{
			append_manifest_lint "${REPO_ROOT}/Cargo.toml: missing version"
			record_failure "manifest SDK version sync" "missing Cargo.toml version"
			return 1
		}

	if [[ "${py_version}" != "${cargo_version}" ]]; then
		append_manifest_lint "sdk/python/pyproject.toml version ${py_version} != Cargo.toml ${cargo_version}"
	fi
	if [[ "${npm_version}" != "${cargo_version}" ]]; then
		append_manifest_lint "sdk/typescript/package.json version ${npm_version} != Cargo.toml ${cargo_version}"
	fi
	if [[ "${go_version}" != "${cargo_version}" ]]; then
		append_manifest_lint "sdk/go/moduleversion/version.go version ${go_version} != Cargo.toml ${cargo_version}"
	fi
	if [[ "${cmake_version}" != "${cargo_version}" ]]; then
		append_manifest_lint "sdk/c/CMakeLists.txt VERSION ${cmake_version} != Cargo.toml ${cargo_version}"
	fi

	if [[ "${py_version}" != "${cargo_version}" ||
		"${npm_version}" != "${cargo_version}" ||
		"${go_version}" != "${cargo_version}" ||
		"${cmake_version}" != "${cargo_version}" ]]; then
		record_failure "manifest SDK version sync" "run ./scripts/publish/sync-version.sh"
		return 1
	fi

	record_ok "manifest SDK version sync"
}

lint_pyproject_ranges() {
	local label="$1"
	local file="$2"
	local lineno spec content
	local issues=0

	[[ -f "${file}" ]] || return 0

	while IFS= read -r content; do
		lineno="${content%%:*}"
		content="${content#*:}"
		[[ "${content}" =~ ^[[:space:]]*\"([^\"]+)\",[[:space:]]*$ ]] || continue
		spec="${BASH_REMATCH[1]}"
		[[ "${spec}" == *" @ "* ]] && continue
		[[ "${spec}" == *"=="* ]] && continue
		if [[ "${spec}" == *">="* || "${spec}" == *"~="* || "${spec}" == *"<="* ||
			"${spec}" == *"^"* || "${spec}" == *"<"* || "${spec}" == *">"* ]]; then
			append_manifest_lint "${file}:${lineno}: loose Python specifier: \"${spec}\""
			issues=$((issues + 1))
		fi
	done < <(grep -En '^[[:space:]]*"[^"]+",?$' "${file}" || true)

	while IFS= read -r content; do
		lineno="${content%%:*}"
		content="${content#*:}"
		if [[ "${content}" == *"requires"* && (
			"${content}" == *">="* || "${content}" == *"~="* || "${content}" == *"<="* ||
			"${content}" == *"^"* || "${content}" == *"<"* || "${content}" == *">"*) ]] \
			; then
			append_manifest_lint "${file}:${lineno}: loose build-system requires"
			issues=$((issues + 1))
		fi
	done < <(grep -En 'requires\s*=' "${file}" || true)

	if [[ "${issues}" -gt 0 ]]; then
		record_failure "manifest ${label}" "${issues} loose Python specifier(s)"
		return 1
	fi
	record_ok "manifest ${label}"
}

lint_package_json_ranges() {
	local label="$1"
	local file="$2"
	local lineno content
	local issues=0

	[[ -f "${file}" ]] || return 0

	while IFS= read -r content; do
		lineno="${content%%:*}"
		content="${content#*:}"
		if [[ "${content}" == *'"^'* || "${content}" == *'"~'* ||
			"${content}" == *'">='* || "${content}" == *'"<='* ||
			"${content}" == *'"<'* || "${content}" == *'"*'* ]]; then
			append_manifest_lint "${file}:${lineno}: loose npm range"
			issues=$((issues + 1))
		fi
	done < <(
		awk '
			/"(dependencies|devDependencies|peerDependencies|optionalDependencies)"/ { in_deps=1; next }
			in_deps && /^[[:space:]]*\}/ { in_deps=0; next }
			in_deps { print NR ":" $0 }
		' "${file}"
	)

	if [[ "${issues}" -gt 0 ]]; then
		record_failure "manifest ${label}" "${issues} loose npm range(s)"
		return 1
	fi
	record_ok "manifest ${label}"
}

lint_cmake_project_version() {
	local label="$1"
	local file="$2"
	local cargo_version cmake_version

	[[ -f "${file}" ]] || return 0

	cargo_version="$(read_cargo_version)"
	cmake_version="$(read_cmake_project_version)"
	if [[ -z "${cmake_version}" ]]; then
		append_manifest_lint "${file}: missing project(chunk-your-tools-c VERSION ...)"
		record_failure "manifest ${label}" "missing project VERSION"
		return 1
	fi
	if [[ "${cargo_version}" != "${cmake_version}" ]]; then
		append_manifest_lint "${file}: VERSION ${cmake_version} != Cargo.toml ${cargo_version}"
		record_failure "manifest ${label}" "version out of sync with Cargo.toml"
		return 1
	fi
	record_ok "manifest ${label}"
}

verify_manifests() {
	local had_failure=0
	local pyproject="${REPO_ROOT}/sdk/python/pyproject.toml"
	local npm_root="${REPO_ROOT}/package.json"
	local npm_ts="${REPO_ROOT}/sdk/typescript/package.json"

	lint_sdk_version_sync || had_failure=1

	lint_cmake_project_version "CMakeLists.txt (sdk/c)" \
		"${REPO_ROOT}/sdk/c/CMakeLists.txt" || had_failure=1

	# Manifest ranges are allowed when a lockfile pins resolved versions.
	# Cargo.toml is not linted here — the rust lock step verifies lock coverage
	# and rejects exact (=) pins in the manifest.
	if [[ ! -f "${REPO_ROOT}/sdk/python/uv.lock" ]]; then
		lint_pyproject_ranges "pyproject.toml (sdk/python)" "${pyproject}" || had_failure=1
	fi
	if [[ ! -f "${REPO_ROOT}/package-lock.json" ]]; then
		lint_package_json_ranges "package.json (root)" "${npm_root}" || had_failure=1
	fi
	if [[ ! -f "${REPO_ROOT}/sdk/typescript/package-lock.json" ]]; then
		lint_package_json_ranges "package.json (sdk/typescript)" "${npm_ts}" || had_failure=1
	fi

	if [[ "${DO_REPORT}" -eq 1 && -s "${MANIFEST_LINT_FILE}" ]]; then
		write_summary_line "manifest lint findings -> manifest-lint.txt"
	fi

	return "${had_failure}"
}

if [[ "${SHORT}" -eq 0 ]]; then
	info "repo: ${REPO_ROOT}"
fi

if [[ "${SKIP_PYTHON}" -eq 0 ]]; then
	run_step "python lock (sdk/python)" verify_python_lock "sdk/python" "${REPO_ROOT}/sdk/python"
fi

if [[ "${SKIP_RUST}" -eq 0 ]]; then
	run_step "rust lock (workspace)" verify_rust_lock "workspace" "${REPO_ROOT}"
fi

if [[ "${SKIP_C}" -eq 0 ]]; then
	run_step "c sdk (sdk/c)" verify_c_sdk
fi

if [[ "${SKIP_GO}" -eq 0 ]]; then
	run_step "go lock (sdk/go)" verify_go_lock
fi

if [[ "${SKIP_NPM}" -eq 0 ]]; then
	run_step "npm lock (root)" verify_npm_lock "root" "${REPO_ROOT}"
	run_step "npm lock (sdk/typescript)" verify_npm_lock "sdk/typescript" "${REPO_ROOT}/sdk/typescript"
fi

if [[ "${DO_MANIFEST_LINT}" -eq 1 ]]; then
	run_step "manifest lint" verify_manifests
fi

if [[ "${SHORT}" -eq 0 ]]; then
	echo ""
fi
if [[ "${DO_REPORT}" -eq 1 ]]; then
	write_summary_line ""
	write_summary_line "finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
	write_summary_line "failures: ${FAILURES}"
	if [[ "${SHORT}" -eq 0 ]]; then
		info "summary: ${DEPS_SUMMARY_FILE}"
	fi
fi

if [[ "${FAILURES}" -gt 0 ]]; then
	die "${FAILURES} check(s) failed"
fi

if [[ "${SHORT}" -eq 1 ]]; then
	printf 'all pin checks passed\n'
else
	info "all pin checks passed"
fi
