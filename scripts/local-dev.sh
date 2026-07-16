#!/usr/bin/env bash
# Local SDK monorepo workflow: Rust core → SDK artifacts (no registry publish).
#
# Usage:
#   ./scripts/local-dev.sh [--short|--silent] <command> [args...]
#
# Options:
#   --short | --silent   Only print error/warning lines (hide info/success noise)
#
# Commands:
#   Core (Rust):
#     core-rust | rust     cargo test -p chunk-your-tools + release CLI catalog build
#     indexer [subcmd]     chunk-your-tools decompose / recompose (see help)
#
#   SDKs:
#     sdk-python           maturin develop --release + verify sdk/python
#     sdk-verify           verify sdk/python install + native import
#     sdk-typescript       npm ci, build, test (sdk/typescript)
#     sdk-c                cmake build + ctest (sdk/c)
#     sdk-go               build C FFI + go test (sdk/go)
#     sdk-all              all SDK targets above
#
#   Other:
#     simulate-registry    isolated venv: install built wheels + cargo/npm dry-run checks
#     ci                   sdk-python verify + ast-grep scan + pytest (sdk/python)
#     all                  core-rust → all SDKs (full monorepo check)
#
# Examples:
#   ./scripts/local-dev.sh all
#   ./scripts/local-dev.sh --silent sdk-go
#   KEEP_SIM_DIR=1 ./scripts/local-dev.sh simulate-registry
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/local-dev-lib.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/shorten-paths.sh"
export SHORTEN_ROOT="${CHUNK_YOUR_TOOLS_REPO_ROOT}"

CHUNK_YOUR_TOOLS_LOCAL_DEV_SHORT="${CHUNK_YOUR_TOOLS_LOCAL_DEV_SHORT:-}"
LOCAL_DEV_ARGS=()
while (($#)); do
	case "$1" in
	--short | --silent)
		CHUNK_YOUR_TOOLS_LOCAL_DEV_SHORT=1
		shift
		;;
	*)
		LOCAL_DEV_ARGS+=("$1")
		shift
		;;
	esac
done
export CHUNK_YOUR_TOOLS_LOCAL_DEV_SHORT

usage() {
	sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
}

_chunk_your_tools_local_dev_main() {
	local cmd="${1:-}"
	shift || true

	case "${cmd}" in
	core-rust | rust)
		require_repo_root
		chunk_your_tools_build_rust
		;;
	indexer)
		require_repo_root
		require_cmd jq
		sub="${1:-all}"
		shift || true
		case "${sub}" in
		decompose | build)
			chunk_your_tools_indexer_build_catalog
			;;
		survivors)
			chunk_your_tools_indexer_extract_survivors
			;;
		recompose | retrieve)
			chunk_your_tools_indexer_retrieve "$@"
			;;
		all)
			chunk_your_tools_indexer_all "$@"
			;;
		-h | --help | help)
			cat <<EOF
Usage: ./scripts/local-dev.sh indexer [decompose|survivors|recompose|all] [args...]

  decompose   extract tools from examples/input/tools.json -> chunk-your-tools decompose -> .catalog/
  survivors   extract legacy json/md survivors from example rerank output
  recompose   chunk-your-tools recompose (in-memory, no catalog dir required)
  all         decompose + survivors + recompose
EOF
			;;
		*)
			die "unknown indexer subcommand: ${sub} (try: decompose, survivors, recompose, all)"
			;;
		esac
		;;
	sdk-python)
		require_repo_root
		chunk_your_tools_build_sdk_python
		chunk_your_tools_verify_sdk_python
		;;
	sdk-verify)
		require_repo_root
		chunk_your_tools_verify_sdk_python
		;;
	sdk-typescript)
		require_repo_root
		chunk_your_tools_build_sdk_typescript
		;;
	sdk-c)
		require_repo_root
		chunk_your_tools_build_sdk_c
		;;
	sdk-go)
		require_repo_root
		chunk_your_tools_build_sdk_go
		;;
	sdk-all)
		require_repo_root
		chunk_your_tools_section "SDK: Python"
		chunk_your_tools_build_sdk_python
		chunk_your_tools_verify_sdk_python
		chunk_your_tools_section "SDK: C"
		chunk_your_tools_build_sdk_c
		chunk_your_tools_section "SDK: Go"
		chunk_your_tools_build_sdk_go
		chunk_your_tools_section "SDK: TypeScript"
		chunk_your_tools_build_sdk_typescript
		;;
	verify)
		require_repo_root
		chunk_your_tools_verify_sdk_python
		;;
	simulate-registry)
		require_repo_root
		require_cmd uv
		require_cmd cargo
		require_cmd npm
		chunk_your_tools_build_sdk_python
		chunk_your_tools_build_rust

		SIM_DIR="${CHUNK_YOUR_TOOLS_SIM_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/chunk-your-tools-local-dev.XXXXXX")}"
		KEEP_SIM_DIR="${KEEP_SIM_DIR:-}"
		trap '[[ -n "${KEEP_SIM_DIR}" ]] || rm -rf "${SIM_DIR}"' EXIT

		info "simulate registry install"
		mkdir -p "${SIM_DIR}/dist-sdk" "${SIM_DIR}/npm-pack"

		info "build chunk-your-tools wheel"
		chunk_your_tools_run bash -c "cd \"${CHUNK_YOUR_TOOLS_REPO_ROOT}/sdk/python\" && uv build -o \"${SIM_DIR}/dist-sdk\""

		info "cargo publish --dry-run"
		chunk_your_tools_run bash -c "cd \"${CHUNK_YOUR_TOOLS_REPO_ROOT}\" && cargo publish -p chunk-your-tools --dry-run"

		info "npm pack"
		chunk_your_tools_run bash -c "cd \"${CHUNK_YOUR_TOOLS_REPO_ROOT}/sdk/typescript\" && npm ci && npm run build && npm pack --pack-destination \"${SIM_DIR}/npm-pack\""

		SIM_VENV="${SIM_DIR}/venv"
		chunk_your_tools_run uv venv "${SIM_VENV}"
		# shellcheck disable=SC1091
		source "${SIM_VENV}/bin/activate"
		info "install wheels in isolated venv"
		SDK_WHL=("${SIM_DIR}"/dist-sdk/chunk_your_tools-*.whl)
		[[ -f "${SDK_WHL[0]}" ]] || die "SDK wheel not found under ${SIM_DIR}/dist-sdk"
		chunk_your_tools_run uv pip install "${SDK_WHL[0]}"

		info "smoke imports"
		chunk_your_tools_run python - <<'PY'
from importlib import metadata

from chunk_your_tools._native import build_catalog_index as native_build
from chunk_your_tools.build import build_catalog_index as sdk_build

assert callable(native_build)
assert callable(sdk_build)
print("OK: isolated wheel install")
print("  chunk-your-tools:", metadata.version("chunk-your-tools"))
PY

		deactivate 2>/dev/null || true

		info "simulate-registry done (${SIM_DIR})"
		if [[ -n "${KEEP_SIM_DIR}" ]]; then
			trap - EXIT
			info "KEEP_SIM_DIR=1 — directory kept"
		fi
		;;
	all)
		require_repo_root
		chunk_your_tools_run_all
		info "all done"
		;;
	ci)
		require_repo_root
		chunk_your_tools_section "CI"
		chunk_your_tools_verify_sdk_python
		chunk_your_tools_verify_sdk_import
		if command -v ast-grep >/dev/null 2>&1; then
			info "ast-grep scan"
			chunk_your_tools_run ast-grep scan sdk/
		else
			info "skip ast-grep (not on PATH)"
		fi
		chunk_your_tools_test_sdk_python
		;;
	"" | -h | --help | help)
		usage
		;;
	*)
		if [[ -n "${CHUNK_YOUR_TOOLS_LOCAL_DEV_SHORT:-}" ]]; then
			die "unknown command: ${cmd}"
		fi
		echo "unknown command: ${cmd}" >&2
		echo >&2
		usage >&2
		return 1
		;;
	esac
}

if [[ -n "${CHUNK_YOUR_TOOLS_LOCAL_DEV_SHORT}" ]]; then
	_chunk_your_tools_local_dev_main "${LOCAL_DEV_ARGS[@]}" 2>&1 | shorten_paths | chunk_your_tools_filter_short_logs
else
	_chunk_your_tools_local_dev_main "${LOCAL_DEV_ARGS[@]}" 2>&1 | shorten_paths
fi
exit "${PIPESTATUS[0]}"
