#!/usr/bin/env bash
# Build libchunk_your_tools in CHUNK_YOUR_TOOLS_E2E_STAGING for Go/C E2E harnesses.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGING="${CHUNK_YOUR_TOOLS_E2E_STAGING:?run prepare-release-checkout.sh first}"
TRIPLET="${CHUNK_YOUR_TOOLS_RUST_TARGET:-$("${ROOT}/scripts/host-rust-target.sh")}"
PROFILE="${CHUNK_YOUR_TOOLS_C_LIB_PROFILE:-release}"

release_flag=(--release)
if [[ "$PROFILE" == "debug" ]]; then
	release_flag=()
fi

if [[ ! -f "${STAGING}/Cargo.toml" ]]; then
	echo "::error::missing Cargo.toml in CHUNK_YOUR_TOOLS_E2E_STAGING=${STAGING}" >&2
	exit 1
fi

# cgo in sdk/go links ${SRCDIR}/../../target/<triplet>/<profile>; keep artifacts there.
export CARGO_TARGET_DIR="${STAGING}/target"

rustup target add "$TRIPLET" >/dev/null 2>&1 || true

host="$("${ROOT}/scripts/host-rust-target.sh")"
target_args=(--target "$TRIPLET")
artifact_dir="${CARGO_TARGET_DIR}/${TRIPLET}/${PROFILE}"
if [[ "$TRIPLET" == "$host" ]]; then
	# Host builds also populate target/<profile>/; cgo expects target/<triplet>/<profile>/.
	target_args=(--target "$TRIPLET")
fi

echo "Building chunk-your-tools ffi in ${STAGING} for ${TRIPLET}/${PROFILE}" >&2
(
	cd "$STAGING"
	cargo clean -p chunk-your-tools --target "$TRIPLET" >/dev/null 2>&1 || true
	cargo build -p chunk-your-tools --no-default-features --features ffi \
		"${target_args[@]}" "${release_flag[@]}"
)

if [[ "$TRIPLET" == "$host" && ! -f "${artifact_dir}/libchunk_your_tools.dylib" && ! -f "${artifact_dir}/libchunk_your_tools.so" && ! -f "${artifact_dir}/chunk_your_tools.dll" ]]; then
	host_dir="${CARGO_TARGET_DIR}/${PROFILE}"
	mkdir -p "$artifact_dir"
	shopt -s nullglob
	for artifact in "${host_dir}/libchunk_your_tools.dylib" "${host_dir}/libchunk_your_tools.so" \
		"${host_dir}/chunk_your_tools.dll" "${host_dir}/chunk_your_tools.dll.lib" \
		"${host_dir}/libchunk_your_tools.a" "${host_dir}/chunk_your_tools.lib"; do
		if [[ -f "$artifact" ]]; then
			cp -f "$artifact" "${artifact_dir}/$(basename "$artifact")"
		fi
	done
	shopt -u nullglob
fi

header_src="${STAGING}/chunk_your_tools.h"
header_dst="${STAGING}/sdk/c/include/chunk_your_tools.h"
[[ -f "$header_src" ]] || {
	echo "::error::missing generated header: ${header_src}" >&2
	exit 1
}
mkdir -p "$(dirname "$header_dst")"
cp "$header_src" "$header_dst"
echo "Synced header -> ${header_dst}" >&2

shared=""
case "${TRIPLET}" in
*-pc-windows-msvc) shared="${artifact_dir}/chunk_your_tools.dll" ;;
*-apple-darwin) shared="${artifact_dir}/libchunk_your_tools.dylib" ;;
*) shared="${artifact_dir}/libchunk_your_tools.so" ;;
esac
[[ -f "$shared" ]] || {
	echo "::error::missing shared library: ${shared}" >&2
	exit 1
}
