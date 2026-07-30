#!/usr/bin/env bash
# Audit C SDK (sdk/c) first-party license metadata.
#
# Usage:
#   ./scripts/legal/audit-c.sh [--output-dir DIR] [--check] [--report]
#
# The C SDK ships headers and links the Rust FFI crate; dependency licenses are
# covered by audit-rust.sh (cargo-deny). This step records sdk/c LICENSE metadata.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/legal/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

OUTPUT_DIR=""
DO_CHECK=1
DO_REPORT=1

while [[ $# -gt 0 ]]; do
	case "$1" in
	--output-dir)
		[[ $# -ge 2 ]] || legal_die "--output-dir requires a path"
		OUTPUT_DIR="$2"
		shift 2
		;;
	--output-dir=*)
		OUTPUT_DIR="${1#*=}"
		shift
		;;
	--check)
		DO_CHECK=1
		shift
		;;
	--no-check)
		DO_CHECK=0
		shift
		;;
	--report)
		DO_REPORT=1
		shift
		;;
	--no-report)
		DO_REPORT=0
		shift
		;;
	-h | --help)
		cat <<'EOF'
Usage: audit-c.sh [--output-dir DIR] [--check] [--no-check] [--report] [--no-report]

Writes first-party license metadata for sdk/c (FFI headers and release artifacts).
Native dependency licenses are audited separately via audit-rust.sh.
EOF
		exit 0
		;;
	*)
		legal_die "unknown arg: $1 (try --help)"
		;;
	esac
done

legal_require_repo_root
legal_require_cmd python3

C_SDK_DIR="${LEGAL_REPO_ROOT}/sdk/c"
[[ -d "${C_SDK_DIR}" ]] || legal_die "missing ${C_SDK_DIR}"

if [[ -n "${OUTPUT_DIR}" ]]; then
	legal_init_output_dir "${OUTPUT_DIR}"
elif [[ -n "${LEGAL_OUTPUT_DIR:-}" ]]; then
	:
else
	legal_init_output_dir ""
fi

if [[ "${DO_REPORT}" -eq 1 ]]; then
	legal_info "c sdk/c: first-party license report"
	python3 "${SCRIPT_DIR}/lib/report-c-sdk.py" \
		"${LEGAL_REPO_ROOT}" "${LEGAL_OUTPUT_DIR}"
	legal_write_summary_line "c sdk/c: report -> c-sdk.{json,md}"
fi

if [[ "${DO_CHECK}" -eq 1 ]]; then
	legal_info "c sdk/c: license policy check"
	[[ -f "${C_SDK_DIR}/LICENSE" ]] ||
		legal_die "c sdk/c: missing LICENSE (expected ${C_SDK_DIR}/LICENSE)"

	license="$(
		python3 - "${LEGAL_REPO_ROOT}/Cargo.toml" <<'PY'
import sys

try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib  # type: ignore[no-redef]

with open(sys.argv[1], "rb") as handle:
    data = tomllib.load(handle)
package = data.get("package", {})
print(package.get("license", ""))
PY
	)"
	[[ -n "${license}" ]] || legal_die "c sdk/c: missing license in Cargo.toml"
	if ! legal_license_allowed "${license}"; then
		legal_die "c sdk/c: license '${license}' not in allow-list"
	fi
	legal_write_summary_line "c sdk/c: LICENSE present; license ${license} allowed"
fi
