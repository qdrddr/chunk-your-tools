#!/usr/bin/env bash
# Shared repo-root resolution for examples/*.sh

cyt_examples_dir_for_script() {
	local script="$1"
	local script_name
	script_name="$(basename "$script")"

	while [[ -L "$script" ]]; do
		local link_dir
		link_dir="$(cd "$(dirname "$script")" && pwd)"
		script="$(readlink "$script")"
		[[ "$script" != /* ]] && script="${link_dir}/${script}"
	done

	local script_dir
	if [[ "$script" == */* ]]; then
		script_dir="$(cd "$(dirname "$script")" && pwd)"
	elif [[ -f "${PWD}/examples/${script_name}" ]]; then
		script_dir="$(cd "${PWD}/examples" && pwd)"
	elif [[ -f "${PWD}/${script_name}" ]]; then
		script_dir="$(cd "$(dirname "${PWD}/${script_name}")" && pwd)"
	else
		script_dir="$PWD"
	fi

	if [[ "$(basename "$script_dir")" == "examples" ]]; then
		echo "$script_dir"
		return 0
	fi
	if [[ -d "${script_dir}/examples" ]]; then
		(cd "${script_dir}/examples" && pwd)
		return 0
	fi
	echo "$script_dir"
}

cyt_repo_root_from() {
	local examples_dir
	examples_dir="$(cyt_examples_dir_for_script "$1")"

	if [[ "$(basename "$examples_dir")" == "examples" ]]; then
		(cd "${examples_dir}/.." && pwd)
		return 0
	fi

	local dir="$examples_dir"
	while [[ "$dir" != "/" ]]; do
		if [[ -f "${dir}/Cargo.toml" ]] &&
			grep -qE '^name = "chunk-your-tools"' "${dir}/Cargo.toml" 2>/dev/null; then
			echo "$dir"
			return 0
		fi
		dir="$(dirname "$dir")"
	done

	(cd "${examples_dir}/.." && pwd)
}
