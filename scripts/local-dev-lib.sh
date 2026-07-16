#!/usr/bin/env bash
# shellcheck shell=bash
# Shared helpers for local monorepo development (source scripts/local-dev-lib.sh).
# Not meant to be executed directly.

if [[ -z "${CHUNK_YOUR_TOOLS_LOCAL_DEV_LIB_SOURCED:-}" ]]; then
	CHUNK_YOUR_TOOLS_LOCAL_DEV_LIB_SOURCED=1

	CHUNK_YOUR_TOOLS_REPO_ROOT="${CHUNK_YOUR_TOOLS_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
	export CHUNK_YOUR_TOOLS_REPO_ROOT

	CHUNK_YOUR_TOOLS_VENV_BIN="${CHUNK_YOUR_TOOLS_REPO_ROOT}/.venv/bin"
	export PATH="${CHUNK_YOUR_TOOLS_VENV_BIN}:${PATH}"

	die() {
		echo "error: $*" >&2
		exit 1
	}

	info() {
		[[ -n "${CHUNK_YOUR_TOOLS_LOCAL_DEV_SHORT:-}" ]] && return 0
		echo "==> $*"
	}

	chunk_your_tools_section() {
		[[ -n "${CHUNK_YOUR_TOOLS_LOCAL_DEV_SHORT:-}" ]] && return 0
		echo ""
		echo "$*"
	}

	# Run a command; suppress stdout in short/silent mode (stderr still visible).
	chunk_your_tools_run() {
		if [[ -n "${CHUNK_YOUR_TOOLS_LOCAL_DEV_SHORT:-}" ]]; then
			"$@" >/dev/null
		else
			"$@"
		fi
	}

	# Keep only error/warning lines when CHUNK_YOUR_TOOLS_LOCAL_DEV_SHORT is set (pipe after shorten_paths).
	chunk_your_tools_filter_short_logs() {
		awk '
			BEGIN {
				IGNORECASE = 1
				ld_grp_count = 0
				ld_grp_key = ""
				ld_grp_header = ""
				ld_grp_max_items = 8
			}

			function ld_grp_flush(    i, shown, more) {
				if (ld_grp_count == 0) return
				print ld_grp_header (ld_grp_count > 1 ? " [" ld_grp_count " members]" : "")
				shown = ld_grp_count
				if (shown > ld_grp_max_items) shown = ld_grp_max_items
				for (i = 1; i <= shown; i++) print ld_grp_items[i]
				more = ld_grp_count - shown
				if (more > 0) print "... +" more " more members"
				ld_grp_count = 0
				ld_grp_key = ""
				ld_grp_header = ""
				delete ld_grp_items
			}

			# macOS/iOS ld: group archive member version skew warnings.
			# Input:  ld: warning: object file (lib.a[336](obj.o)) was built for newer '"'"'macOS'"'"' version (26.5) than being linked (26.0)
			# Output: ld: warning: object file (lib.a was built for newer '"'"'macOS'"'"' version (26.5) than being linked (26.0) [N members]
			#         [336](obj.o))
			function ld_try_group_object_warning(line,    s, p1, p2, p3, rest, key, header, item, marker) {
				if (line !~ /^ld:[[:space:]]+warning:[[:space:]]+object file \(/)
					return 0
				s = line
				sub(/^ld:[[:space:]]+warning:[[:space:]]+object file \(/, "", s)
				p1 = index(s, "[")
				if (p1 == 0) return 0
				ld_archive = substr(s, 1, p1 - 1)
				rest = substr(s, p1 + 1)
				p2 = index(rest, "](")
				if (p2 == 0) return 0
				ld_idx = substr(rest, 1, p2 - 1)
				rest = substr(rest, p2 + 2)
				marker = ")) was built for newer "
				p3 = index(rest, marker)
				if (p3 == 0) return 0
				ld_obj = substr(rest, 1, p3 - 1)
				rest = substr(rest, p3 + length(marker))
				if (rest !~ /^'"'"'[^'"'"']+'"'"' version \([^)]+\) than being linked \([^)]+\)$/)
					return 0
				ld_os = rest
				sub(/^'"'"'/, "", ld_os)
				sub(/'"'"' version \(.*/, "", ld_os)
				ld_build = rest
				sub(/^'"'"'[^'"'"']+'"'"' version \(/, "", ld_build)
				sub(/\) than being linked \(.*/, "", ld_build)
				ld_link = rest
				sub(/^[^)]+\) than being linked \(/, "", ld_link)
				sub(/\)$/, "", ld_link)

				key = ld_archive SUBSEP ld_os SUBSEP ld_build SUBSEP ld_link
				header = "ld: warning: object file (" ld_archive " was built for newer \047" ld_os "\047 version (" ld_build ") than being linked (" ld_link ")"
				item = "[" ld_idx "](" ld_obj "))"
				if (key != ld_grp_key) ld_grp_flush()
				ld_grp_key = key
				ld_grp_header = header
				ld_grp_count++
				ld_grp_items[ld_grp_count] = item
				return 1
			}

			{
				if (ld_try_group_object_warning($0)) next

				ld_grp_flush()

				if ($0 ~ /^==>/) next
				if ($0 ~ /^OK:/) next
				if ($0 ~ /^  /) next
				if ($0 ~ /^[━=─#]{3,}/) next
				if ($0 ~ /^=+ test session starts/) next
				if ($0 ~ /^=+ FAILURES =+/) { print; next }
				if ($0 ~ /^=+ short test summary/) { print; next }
				if ($0 ~ /^platform /) next
				if ($0 ~ /^collected /) next
				if ($0 ~ /^test result:/) next
				if ($0 ~ /^[[:space:]]*Compiling /) next
				if ($0 ~ /^[[:space:]]*Finished /) next
				if ($0 ~ /^[[:space:]]*Running /) next
				if ($0 ~ /^   Doc-tests /) next
				if ($0 ~ /^running [0-9]+ test/) next
				if ($0 ~ /^test result: ok/) next
				if ($0 ~ /^test .* \.\.\. ok/) next
				if ($0 ~ /^passed, 0 failed/) next
				if ($0 ~ /^error:/) { print; next }
				if ($0 ~ / error:/) { print; next }
				if ($0 ~ /^warning:/) { print; next }
				if ($0 ~ / warning:/) { print; next }
				if ($0 ~ /fatal error/) { print; next }
				if ($0 ~ /undefined symbols/) { print; next }
				if ($0 ~ /^ld: warning: object file \(.*was built for newer /) next
				if ($0 ~ /^ld: /) { print; next }
				if ($0 ~ /^clang: error/) { print; next }
				if ($0 ~ /: error:/) { print; next }
				if ($0 ~ /^\*\*\* /) { print; next }
				if ($0 ~ /npm warn/) { print; next }
				if ($0 ~ /panic!/) { print; next }
				if ($0 ~ /thread .* panicked/) { print; next }
				if ($0 ~ /AssertionError/) { print; next }
				if ($0 ~ /not ok /) { print; next }
				if ($0 ~ /^E[[:space:]]+/) { print; next }
				if ($0 ~ /FAILED/) { print; next }
				if ($0 ~ /failed/ && $0 !~ /0 failed/ && $0 !~ /passed, 0 failed/) { print; next }
				if ($0 ~ /failure/ && $0 !~ /failure info/) { print; next }
				if ($0 ~ /✖/) { print; next }
				if ($0 ~ /sys\.exit/) { print; next }
				if ($0 ~ /unknown command:/) { print; next }
			}

			END { ld_grp_flush() }
		'
	}

	require_cmd() {
		command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
	}

	chunk_your_tools_cmake_make_program() {
		local candidate
		for candidate in gmake make; do
			if command -v "$candidate" >/dev/null 2>&1; then
				command -v "$candidate"
				return 0
			fi
		done
		die "missing required command: make or gmake"
	}

	chunk_your_tools_npm() {
		env -u npm_config_devdir npm "$@"
	}

	require_repo_root() {
		[[ -f "${CHUNK_YOUR_TOOLS_REPO_ROOT}/Cargo.toml" ]] || die "not a repo root: ${CHUNK_YOUR_TOOLS_REPO_ROOT}"
		[[ -f "${CHUNK_YOUR_TOOLS_REPO_ROOT}/sdk/python/pyproject.toml" ]] || die "missing sdk/python"
		[[ -f "${CHUNK_YOUR_TOOLS_REPO_ROOT}/src/lib.rs" ]] || die "missing src/lib.rs"
	}

	chunk_your_tools_sync_sdk_python() {
		require_cmd uv
		cd "${CHUNK_YOUR_TOOLS_REPO_ROOT}/sdk/python" || die "cd failed"
		info "uv sync sdk/python"
		chunk_your_tools_run uv sync
	}

	chunk_your_tools_indexer_release() {
		require_cmd cargo
		cd "${CHUNK_YOUR_TOOLS_REPO_ROOT}" || die "cd failed"
		info "cargo build -p chunk-your-tools --release"
		chunk_your_tools_run env -u CARGO_TARGET_DIR cargo build -p chunk-your-tools --release
	}

	chunk_your_tools_indexer_paths() {
		CHUNK_YOUR_TOOLS_INDEXER_BIN="${CHUNK_YOUR_TOOLS_REPO_ROOT}/target/release/chunk-your-tools"
		CHUNK_YOUR_TOOLS_CATALOG_DIR="${CHUNK_YOUR_TOOLS_CATALOG_DIR:-${CHUNK_YOUR_TOOLS_REPO_ROOT}/.catalog}"
		CHUNK_YOUR_TOOLS_EXAMPLE_JSON="${CHUNK_YOUR_TOOLS_EXAMPLE_JSON:-${CHUNK_YOUR_TOOLS_REPO_ROOT}/debug/full_example.json}"
		CHUNK_YOUR_TOOLS_SURVIVORS_JSON="${CHUNK_YOUR_TOOLS_SURVIVORS_JSON:-${CHUNK_YOUR_TOOLS_CATALOG_DIR}/survivors.json}"
		CHUNK_YOUR_TOOLS_RETRIEVE_OUT="${CHUNK_YOUR_TOOLS_RETRIEVE_OUT:-${CHUNK_YOUR_TOOLS_CATALOG_DIR}/out.json}"
	}

	chunk_your_tools_indexer_build_catalog() {
		require_cmd jq
		chunk_your_tools_indexer_paths

		local example="${CHUNK_YOUR_TOOLS_EXAMPLE_JSON}"
		[[ -f "${example}" ]] || die "missing ${example}"

		chunk_your_tools_indexer_release
		[[ -x "${CHUNK_YOUR_TOOLS_INDEXER_BIN}" ]] || die "chunk-your-tools binary not found at ${CHUNK_YOUR_TOOLS_INDEXER_BIN}"

		local tools_json
		tools_json="$(mktemp "${TMPDIR:-/tmp}/chunk-your-tools-tools.XXXXXX")"

		info "extract tools from example json"
		chunk_your_tools_run jq '.body.tools' "${example}" >"${tools_json}"

		mkdir -p "${CHUNK_YOUR_TOOLS_CATALOG_DIR}"
		info "chunk-your-tools decompose"
		chunk_your_tools_run "${CHUNK_YOUR_TOOLS_INDEXER_BIN}" decompose --input "${tools_json}" --output "${CHUNK_YOUR_TOOLS_CATALOG_DIR}"
		rm -f "${tools_json}"

		local decomposed_count
		decomposed_count="$(find "${CHUNK_YOUR_TOOLS_CATALOG_DIR}/schemas/decomposed" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
		[[ "${decomposed_count}" -gt 0 ]] || die "expected decomposed json files, got ${decomposed_count}"
		info "decompose ok (${decomposed_count} files)"
	}

	chunk_your_tools_indexer_extract_survivors() {
		require_cmd jq
		chunk_your_tools_indexer_paths

		local example="${CHUNK_YOUR_TOOLS_EXAMPLE_JSON}"
		[[ -f "${example}" ]] || die "missing ${example}"
		mkdir -p "${CHUNK_YOUR_TOOLS_CATALOG_DIR}"

		info "extract rerank survivors"
		chunk_your_tools_run jq '{
		  json: [.pruning.decomposed_catalog.rerank.json[]? | .score |= (tonumber)],
		  md:   [.pruning.decomposed_catalog.rerank.md[]?   | .score |= (tonumber)]
		}' "${example}" >"${CHUNK_YOUR_TOOLS_SURVIVORS_JSON}"

		local json_count md_count
		json_count="$(jq '.json | length' "${CHUNK_YOUR_TOOLS_SURVIVORS_JSON}")"
		md_count="$(jq '.md | length' "${CHUNK_YOUR_TOOLS_SURVIVORS_JSON}")"
		[[ "${json_count}" -gt 0 || "${md_count}" -gt 0 ]] ||
			die "no rerank survivors in ${example} (.pruning.decomposed_catalog.rerank)"
		info "survivors ok (json=${json_count}, md=${md_count})"
	}

	chunk_your_tools_indexer_retrieve() {
		chunk_your_tools_indexer_paths
		[[ -f "${CHUNK_YOUR_TOOLS_SURVIVORS_JSON}" ]] || chunk_your_tools_indexer_extract_survivors
		[[ -x "${CHUNK_YOUR_TOOLS_INDEXER_BIN}" ]] || chunk_your_tools_indexer_release
		[[ -x "${CHUNK_YOUR_TOOLS_INDEXER_BIN}" ]] || die "chunk-your-tools binary not found at ${CHUNK_YOUR_TOOLS_INDEXER_BIN}"

		local example="${CHUNK_YOUR_TOOLS_EXAMPLE_JSON}"
		[[ -f "${example}" ]] || die "missing ${example}"

		local tools_json
		tools_json="$(mktemp "${TMPDIR:-/tmp}/chunk-your-tools-tools.XXXXXX")"
		chunk_your_tools_run jq '.body.tools' "${example}" >"${tools_json}"

		local system_policy="${CHUNK_YOUR_TOOLS_INDEXER_SYSTEM_POLICY:-prune_optional}"
		local mcp_policy="${CHUNK_YOUR_TOOLS_INDEXER_MCP_POLICY:-prune_all}"
		local tool_policies=()
		local default_tool_policies="AskUserQuestion=always_include"
		local policy_source="${CHUNK_YOUR_TOOLS_INDEXER_TOOL_POLICIES-${default_tool_policies}}"
		if [[ -n "${policy_source}" ]]; then
			local spec
			for spec in ${policy_source}; do
				tool_policies+=(--tool-policy "${spec}")
			done
		fi

		while [[ $# -gt 0 ]]; do
			case "$1" in
			--tool-policy)
				[[ $# -ge 2 ]] || die "missing value for --tool-policy"
				tool_policies+=(--tool-policy "$2")
				shift 2
				;;
			--tool-policy=*)
				tool_policies+=("$1")
				shift
				;;
			--system-policy)
				[[ $# -ge 2 ]] || die "missing value for --system-policy"
				system_policy="$2"
				shift 2
				;;
			--system-policy=*)
				system_policy="${1#*=}"
				shift
				;;
			--mcp-policy)
				[[ $# -ge 2 ]] || die "missing value for --mcp-policy"
				mcp_policy="$2"
				shift 2
				;;
			--mcp-policy=*)
				mcp_policy="${1#*=}"
				shift
				;;
			--output)
				[[ $# -ge 2 ]] || die "missing value for --output"
				CHUNK_YOUR_TOOLS_RETRIEVE_OUT="$2"
				shift 2
				;;
			--output=*)
				CHUNK_YOUR_TOOLS_RETRIEVE_OUT="${1#*=}"
				shift
				;;
			--per-tool | --per-tool=* | --config | --config=*)
				tool_policies+=("$1")
				if [[ "$1" != *=* ]]; then
					[[ $# -ge 2 ]] || die "missing value for $1"
					tool_policies+=("$2")
					shift
				fi
				shift
				;;
			*)
				die "unknown indexer retrieve arg: $1"
				;;
			esac
		done

		info "chunk-your-tools recompose"
		chunk_your_tools_run "${CHUNK_YOUR_TOOLS_INDEXER_BIN}" recompose \
			--input "${tools_json}" \
			--survivors "${CHUNK_YOUR_TOOLS_SURVIVORS_JSON}" \
			--output "${CHUNK_YOUR_TOOLS_RETRIEVE_OUT}" \
			--system-policy "${system_policy}" \
			--mcp-policy "${mcp_policy}" \
			"${tool_policies[@]}"
		rm -f "${tools_json}"

		[[ -s "${CHUNK_YOUR_TOOLS_RETRIEVE_OUT}" ]] || die "recompose produced empty ${CHUNK_YOUR_TOOLS_RETRIEVE_OUT}"
		require_cmd jq
		local tool_count
		tool_count="$(jq 'length' "${CHUNK_YOUR_TOOLS_RETRIEVE_OUT}")"
		[[ "${tool_count}" -gt 0 ]] || die "recompose produced no tools in ${CHUNK_YOUR_TOOLS_RETRIEVE_OUT}"
		info "recompose ok (${tool_count} tools)"
	}

	chunk_your_tools_indexer_all() {
		chunk_your_tools_indexer_build_catalog
		chunk_your_tools_indexer_extract_survivors
		chunk_your_tools_indexer_retrieve "$@"
	}

	chunk_your_tools_test_indexer_build() {
		chunk_your_tools_indexer_build_catalog
	}

	chunk_your_tools_build_rust() {
		require_cmd cargo
		cd "${CHUNK_YOUR_TOOLS_REPO_ROOT}" || die "cd failed"
		info "cargo test -p chunk-your-tools"
		chunk_your_tools_run env -u CARGO_TARGET_DIR cargo test -p chunk-your-tools
		chunk_your_tools_test_indexer_build
	}

	chunk_your_tools_build_sdk_python() {
		require_cmd uv
		chunk_your_tools_sync_sdk_python
		cd "${CHUNK_YOUR_TOOLS_REPO_ROOT}/sdk/python" || die "cd failed"
		info "maturin develop --release"
		chunk_your_tools_run uv run maturin develop --release
	}

	chunk_your_tools_build_sdk_typescript() {
		require_cmd npm
		cd "${CHUNK_YOUR_TOOLS_REPO_ROOT}/sdk/typescript" || die "cd failed"
		info "npm ci, build, test"
		chunk_your_tools_run env -u CARGO_TARGET_DIR -u npm_config_devdir npm ci
		chunk_your_tools_run env -u CARGO_TARGET_DIR -u npm_config_devdir npm run build
		chunk_your_tools_run env -u CARGO_TARGET_DIR -u npm_config_devdir npm test
	}

	chunk_your_tools_build_sdk_c() {
		require_cmd cmake
		require_cmd ctest
		require_cmd rustc
		cd "${CHUNK_YOUR_TOOLS_REPO_ROOT}" || die "cd failed"
		local triplet make_prog
		triplet="$(rustc -vV | sed -n 's/^host: //p')"
		make_prog="$(chunk_your_tools_cmake_make_program)"
		info "build C FFI (sdk/c, ${triplet})"
		chunk_your_tools_run env -u CARGO_TARGET_DIR bash sdk/c/scripts/build-c-lib.sh --target "${triplet}"
		info "cmake configure + build"
		chunk_your_tools_run env -u CARGO_TARGET_DIR cmake -S sdk/c -B sdk/c/build \
			-DCMAKE_BUILD_TYPE=Release \
			-DCHUNK_YOUR_TOOLS_RUST_TARGET="${triplet}" \
			-DCMAKE_MAKE_PROGRAM="${make_prog}"
		chunk_your_tools_run env -u CARGO_TARGET_DIR cmake --build sdk/c/build
		info "ctest sdk/c"
		local lib_dir="${CHUNK_YOUR_TOOLS_REPO_ROOT}/target/${triplet}/release"
		case "${triplet}" in
		*-apple-darwin)
			chunk_your_tools_run env -u CARGO_TARGET_DIR \
				DYLD_LIBRARY_PATH="${lib_dir}:${lib_dir}/deps:${DYLD_LIBRARY_PATH:-}" \
				ctest --test-dir sdk/c/build --output-on-failure
			;;
		*-pc-windows-msvc)
			chunk_your_tools_run env -u CARGO_TARGET_DIR \
				PATH="${lib_dir}:${PATH}" \
				ctest --test-dir sdk/c/build --output-on-failure
			;;
		*)
			chunk_your_tools_run env -u CARGO_TARGET_DIR \
				LD_LIBRARY_PATH="${lib_dir}:${lib_dir}/deps:${LD_LIBRARY_PATH:-}" \
				ctest --test-dir sdk/c/build --output-on-failure
			;;
		esac
	}

	chunk_your_tools_build_sdk_go() {
		require_cmd go
		require_cmd rustc
		cd "${CHUNK_YOUR_TOOLS_REPO_ROOT}" || die "cd failed"
		info "build C FFI (sdk/go)"
		chunk_your_tools_run env -u CARGO_TARGET_DIR bash sdk/c/scripts/build-c-lib.sh --no-sync-header
		cd "${CHUNK_YOUR_TOOLS_REPO_ROOT}/sdk/go" || die "cd failed"
		export CGO_ENABLED=1
		local host_triplet
		host_triplet="$(rustc -vV | sed -n 's/^host: //p')"
		export PATH="${CHUNK_YOUR_TOOLS_REPO_ROOT}/target/${host_triplet}/release:${PATH}"
		info "go native ensure"
		chunk_your_tools_run go run ./cmd/chunk-native-ensure -static-only
		info "go test ./..."
		chunk_your_tools_run env -u CARGO_TARGET_DIR go test ./...
	}

	chunk_your_tools_build_all_sdks() {
		chunk_your_tools_build_sdk_python
		chunk_your_tools_build_sdk_c
		chunk_your_tools_build_sdk_go
		chunk_your_tools_build_sdk_typescript
	}

	# Fail if chunk-your-tools is not the checkout under sdk/python (e.g. PyPI-only install).
	chunk_your_tools_verify_sdk_python() {
		require_cmd uv
		cd "${CHUNK_YOUR_TOOLS_REPO_ROOT}/sdk/python" || die "cd failed"
		info "verify sdk/python"
		chunk_your_tools_run uv run python - "${CHUNK_YOUR_TOOLS_REPO_ROOT}" <<'PY'
import json
import sys
from importlib import metadata
from pathlib import Path

root = Path(sys.argv[1]).resolve()
sdk_root = (root / "sdk" / "python").resolve()

try:
    dist = metadata.distribution("chunk-your-tools")
except metadata.PackageNotFoundError:
    sys.exit("chunk-your-tools is not installed; run: ./scripts/local-dev.sh sdk-python")

install_kind = "editable"
try:
    direct = json.loads(dist.read_text("direct_url.json"))
    url = str(direct.get("url", "")).replace("\\", "/")
    if "sdk/python" not in url:
        sys.exit(
            "chunk-your-tools direct_url.json does not point at sdk/python:\n" + url
        )
except FileNotFoundError:
    import chunk_your_tools

    pkg_dir = Path(chunk_your_tools.__file__).resolve()
    if sdk_root not in pkg_dir.parents:
        sys.exit(
            "chunk-your-tools is not loaded from sdk/python\n"
            f"  package file: {pkg_dir}\n"
            f"  expected under: {sdk_root}\n"
            "Run ./scripts/local-dev.sh sdk-python"
        )
    install_kind = "path"

from chunk_your_tools._native import build_catalog_index

if not callable(build_catalog_index):
    sys.exit("chunk_your_tools._native.build_catalog_index is not callable (rebuild with sdk-python)")

print("OK: local chunk-your-tools (sdk/python)")
print(f"  sdk root: {sdk_root}")
print(f"  install: {install_kind}")
PY
	}

	chunk_your_tools_verify_sdk_import() {
		require_cmd uv
		cd "${CHUNK_YOUR_TOOLS_REPO_ROOT}/sdk/python" || die "cd failed"
		chunk_your_tools_run uv run python -c "from chunk_your_tools._native import build_catalog_index; assert callable(build_catalog_index)"
	}

	chunk_your_tools_test_sdk_python() {
		require_cmd uv
		cd "${CHUNK_YOUR_TOOLS_REPO_ROOT}/sdk/python" || die "cd failed"
		info "pytest sdk/python"
		chunk_your_tools_run uv run pytest
	}

	chunk_your_tools_run_all() {
		chunk_your_tools_section "Core (Rust)"
		chunk_your_tools_build_rust

		chunk_your_tools_section "SDK: Python"
		chunk_your_tools_build_sdk_python
		chunk_your_tools_verify_sdk_python

		# C/Go before TypeScript: napi build uses the same dylib name and would
		# overwrite the C FFI shared library if TypeScript ran first.
		chunk_your_tools_section "SDK: C"
		chunk_your_tools_build_sdk_c

		chunk_your_tools_section "SDK: Go"
		chunk_your_tools_build_sdk_go

		chunk_your_tools_section "SDK: TypeScript"
		chunk_your_tools_build_sdk_typescript
	}

fi
