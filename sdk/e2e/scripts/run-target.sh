#!/usr/bin/env bash
# Run one registry E2E harness (render manifests first via run-all.sh or run-local.sh).
# Usage: CHUNK_YOUR_TOOLS_RELEASE_VERSION=x.y.z ./run-target.sh <rust|python|typescript|go|c>
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
	echo "usage: CHUNK_YOUR_TOOLS_RELEASE_VERSION=x.y.z $0 <rust|python|typescript|go|c>" >&2
	exit 1
fi

maybe_wait() {
	if [[ "${SKIP_REGISTRY_WAIT:-}" == "1" ]]; then
		echo "Skipping registry wait for ${1} (SKIP_REGISTRY_WAIT=1)"
		return 0
	fi
	"${ROOT}/scripts/wait-registry.sh" "$2"
}

export_native_lib_path() {
	local staging="${CHUNK_YOUR_TOOLS_E2E_STAGING:?run prepare-release-checkout.sh first}"
	local triplet="${CHUNK_YOUR_TOOLS_RUST_TARGET:-$("${ROOT}/scripts/host-rust-target.sh")}"
	local lib_dir="${staging}/target/${triplet}/release"
	local native_dir="${staging}/sdk/go/native/${triplet}"
	case "$triplet" in
	*-apple-darwin)
		export DYLD_LIBRARY_PATH="${lib_dir}:${native_dir}:${DYLD_LIBRARY_PATH:-}"
		;;
	*-pc-windows-msvc)
		export PATH="${lib_dir}:${native_dir}:${PATH}"
		;;
	*)
		export LD_LIBRARY_PATH="${lib_dir}:${native_dir}:${LD_LIBRARY_PATH:-}"
		;;
	esac
}

prepare_go_c() {
	_chunk_your_tools_e2e_staging="$("${ROOT}/scripts/prepare-release-checkout.sh")"
	export CHUNK_YOUR_TOOLS_E2E_STAGING="$_chunk_your_tools_e2e_staging"
	unset _chunk_your_tools_e2e_staging
	"${ROOT}/scripts/render-manifests.sh"
	"${ROOT}/scripts/ensure-release-native.sh"
}

case "$TARGET" in
rust)
	echo "=== Rust (crates.io) ==="
	maybe_wait "crates.io/chunk-your-tools" crate
	(cd "${ROOT}/rust" && cargo test)
	;;
python)
	echo "=== Python SDK (PyPI) ==="
	maybe_wait "PyPI/chunk-your-tools" pypi-sdk
	(cd "${ROOT}/python" && "${ROOT}/scripts/uv-sync-with-retry.sh" --group test && uv run pytest)
	;;
typescript)
	echo "=== TypeScript SDK (npm) ==="
	maybe_wait "npm/chunk-your-tools" npm
	(cd "${ROOT}/typescript" && npm install && npm test)
	;;
go)
	echo "=== Go SDK (GitHub tag + release C FFI) ==="
	maybe_wait "GitHub tag v${CHUNK_YOUR_TOOLS_RELEASE_VERSION}" tag
	maybe_wait "GitHub sdk/go module tag v${CHUNK_YOUR_TOOLS_RELEASE_VERSION}" go-tag
	maybe_wait "GitHub Release C FFI v${CHUNK_YOUR_TOOLS_RELEASE_VERSION}" release-assets
	prepare_go_c
	export_native_lib_path
	(cd "${ROOT}/go" && CGO_ENABLED=1 go mod tidy && CGO_ENABLED=1 go test ./...)
	;;
c)
	echo "=== C SDK (GitHub tag + release C FFI) ==="
	maybe_wait "GitHub tag v${CHUNK_YOUR_TOOLS_RELEASE_VERSION}" tag
	maybe_wait "GitHub Release C FFI v${CHUNK_YOUR_TOOLS_RELEASE_VERSION}" release-assets
	prepare_go_c
	C_SDK="${CHUNK_YOUR_TOOLS_E2E_STAGING}/sdk/c"
	export CARGO_TARGET_DIR="${CHUNK_YOUR_TOOLS_E2E_STAGING}/target"
	cmake -S "${C_SDK}" -B "${C_SDK}/build" -DCMAKE_BUILD_TYPE=Release \
		-DCHUNK_YOUR_TOOLS_RUST_TARGET="${CHUNK_YOUR_TOOLS_RUST_TARGET:-$("${ROOT}/scripts/host-rust-target.sh")}"
	cmake --build "${C_SDK}/build"
	export_native_lib_path
	ctest --test-dir "${C_SDK}/build" --output-on-failure
	;;
*)
	echo "unknown target: ${TARGET}" >&2
	echo "expected: rust, python, typescript, go, c" >&2
	exit 1
	;;
esac
