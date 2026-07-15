#!/usr/bin/env bash
# Build a MinGW-compatible libchunk_your_tools.a import library from an MSVC chunk_your_tools.dll.
# Go cgo on Windows uses MinGW; Rust CI builds pc-windows-msvc DLLs + import libs.
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: prepare-windows-cgo.sh LIB_DIR [NATIVE_DIR]

Generate libchunk_your_tools.a beside chunk_your_tools.dll for Go cgo (-lchunk_your_tools).
If NATIVE_DIR is set, also copy the .a there for sdk/go/native/<triplet>/.
EOF
}

die() {
	echo "error: $*" >&2
	exit 1
}

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

lib_dir="${1:-}"
native_dir="${2:-}"

if [[ -z "$lib_dir" || "$1" == "-h" || "$1" == "--help" ]]; then
	usage
	exit 0
fi

dll="${lib_dir}/chunk_your_tools.dll"
import_a="${lib_dir}/libchunk_your_tools.a"

[[ -f "$dll" ]] || die "expected DLL missing: $dll"

if [[ -f "$import_a" ]]; then
	if [[ -n "$native_dir" ]]; then
		mkdir -p "$native_dir"
		cp -f "$import_a" "${native_dir}/libchunk_your_tools.a"
	fi
	exit 0
fi

require_cmd gendef
require_cmd dlltool

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cp "$dll" "${tmpdir}/chunk_your_tools.dll"
(
	cd "$tmpdir"
	gendef chunk_your_tools.dll
	dlltool --input-def chunk_your_tools.def --dllname chunk_your_tools.dll --output-lib libchunk_your_tools.a
)

cp "${tmpdir}/libchunk_your_tools.a" "$import_a"
if [[ -n "$native_dir" ]]; then
	mkdir -p "$native_dir"
	cp -f "$import_a" "${native_dir}/libchunk_your_tools.a"
fi

echo "==> prepared MinGW import library: ${import_a}"
