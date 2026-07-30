#!/usr/bin/env bash
# Run C SDK lint/format tools with Homebrew LLVM on PATH when present.
set -euo pipefail

ROOT="$(cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && pwd -P)"
if [[ -d /opt/homebrew/opt/llvm/bin ]]; then
	export PATH="/opt/homebrew/opt/llvm/bin:${PATH}"
elif [[ -d /usr/local/opt/llvm/bin ]]; then
	export PATH="/usr/local/opt/llvm/bin:${PATH}"
fi

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "error: $1 not found (macOS: brew install llvm cppcheck cpplint)" >&2
		exit 1
	}
}

ensure_c_compile_db() {
	local build_dir="${ROOT}/sdk/c/build"
	local lock="${build_dir}/.configure.lock"
	mkdir -p "${build_dir}"
	if [[ -f "${build_dir}/compile_commands.json" ]]; then
		return 0
	fi
	local i=0
	while ! mkdir "${lock}" 2>/dev/null; do
		sleep 0.25
		[[ -f "${build_dir}/compile_commands.json" ]] && return 0
		i=$((i + 1))
		if ((i > 120)); then
			echo "error: timed out waiting for sdk/c compile database" >&2
			return 1
		fi
	done
	if [[ ! -f "${build_dir}/compile_commands.json" ]]; then
		cmake -S "${ROOT}/sdk/c" -B "${build_dir}" \
			-DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_BUILD_TYPE=Release
	fi
	rmdir "${lock}"
}

tool=${1:?usage: c-sdk-precommit.sh TOOL [args...]}
shift

case "$tool" in
clang-format)
	require_cmd clang-format
	exec clang-format "$@"
	;;
clang-tidy)
	require_cmd clang-tidy
	require_cmd cmake
	ensure_c_compile_db
	extra=()
	if sdkroot="$(xcrun --show-sdk-path 2>/dev/null)"; then
		extra+=("-extra-arg=-isysroot${sdkroot}")
		extra+=("-extra-arg=-isystem${sdkroot}/usr/include")
	fi
	exec clang-tidy "${extra[@]}" "$@"
	;;
cppcheck)
	require_cmd cppcheck
	exec cppcheck "$@"
	;;
cpplint)
	if command -v cpplint >/dev/null 2>&1; then
		exec cpplint "$@"
	fi
	cd "$ROOT" || exit 1
	exec uv run cpplint "$@"
	;;
*)
	echo "unknown tool: $tool" >&2
	exit 1
	;;
esac
