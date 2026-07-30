#!/usr/bin/env bash
# Audit Go module dependency licenses via go-licenses.
#
# Usage:
#   ./scripts/legal/audit-go.sh [--output-dir DIR] [--report]
#
# Target: sdk/go/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/legal/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

OUTPUT_DIR=""
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
	--check | --no-check)
		# Accepted for audit-all.sh compatibility; go audit is report-only.
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
Usage: audit-go.sh [--output-dir DIR] [--report] [--no-report]

Downloads Go modules and writes a CSV license report for sdk/go.
EOF
		exit 0
		;;
	*)
		legal_die "unknown arg: $1 (try --help)"
		;;
	esac
done

legal_require_repo_root
legal_require_cmd go

GO_MODULE_DIR="${LEGAL_REPO_ROOT}/sdk/go"
[[ -f "${GO_MODULE_DIR}/go.mod" ]] || legal_die "missing ${GO_MODULE_DIR}/go.mod"

if [[ -n "${OUTPUT_DIR}" ]]; then
	legal_init_output_dir "${OUTPUT_DIR}"
elif [[ -n "${LEGAL_OUTPUT_DIR:-}" ]]; then
	:
else
	legal_init_output_dir ""
fi

legal_go_licenses() {
	if command -v go-licenses >/dev/null 2>&1; then
		go-licenses "$@"
	elif [[ -x "${GOPATH:-${HOME}/go}/bin/go-licenses" ]]; then
		"${GOPATH:-${HOME}/go}/bin/go-licenses" "$@"
	else
		legal_run go run github.com/google/go-licenses/v2@latest "$@"
	fi
}

legal_info "go sdk/go: go mod download"
(
	cd "${GO_MODULE_DIR}"
	legal_run go mod download
)

if [[ "${DO_REPORT}" -eq 1 ]]; then
	legal_info "go sdk/go: go-licenses report"
	(
		cd "${GO_MODULE_DIR}"
		legal_go_licenses report ./... \
			>"${LEGAL_OUTPUT_DIR}/go-sdk.csv"
	)
	legal_write_summary_line "go sdk/go: go-licenses -> go-sdk.csv"
fi
