#!/usr/bin/env bash
# Audit C SDK license metadata (sdk/c has no package-manager dependencies).
#
# The C SDK is a thin header + CMake wrapper over the Rust FFI library.
# Runtime dependency licenses are covered by scripts/legal/audit-rust.sh.
#
# Usage:
#   ./scripts/legal/audit-c.sh [--output-dir DIR] [--check] [--report]
#
# Target: sdk/c/

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

Records sdk/c first-party license metadata and notes that native runtime
dependency licenses are audited via audit-rust.sh (Rust FFI crate).
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
CMAKE_FILE="${C_SDK_DIR}/CMakeLists.txt"
LICENSE_FILE="${C_SDK_DIR}/LICENSE"

[[ -f "${CMAKE_FILE}" ]] || legal_die "missing ${CMAKE_FILE}"
[[ -f "${LICENSE_FILE}" ]] || legal_die "missing ${LICENSE_FILE}"

if [[ -n "${OUTPUT_DIR}" ]]; then
	legal_init_output_dir "${OUTPUT_DIR}"
elif [[ -n "${LEGAL_OUTPUT_DIR:-}" ]]; then
	:
else
	legal_init_output_dir ""
fi

slug="sdk-c"
report_json="${LEGAL_OUTPUT_DIR}/c-${slug}.json"
report_md="${LEGAL_OUTPUT_DIR}/c-${slug}.md"

legal_info "c sdk/c: collect license metadata"
python3 - "${C_SDK_DIR}" "${CMAKE_FILE}" "${LICENSE_FILE}" "${report_json}" "${report_md}" \
	"${DO_REPORT}" "${DO_CHECK}" "$(legal_allowed_licenses)" <<'PY'
import json
import re
import sys
from pathlib import Path

c_dir = Path(sys.argv[1])
cmake_file = Path(sys.argv[2])
license_file = Path(sys.argv[3])
report_json = Path(sys.argv[4])
report_md = Path(sys.argv[5])
do_report = sys.argv[6] == "1"
do_check = sys.argv[7] == "1"
allowed = {item.strip() for item in sys.argv[8].split(";") if item.strip()}

cmake_text = cmake_file.read_text(encoding="utf-8")
match = re.search(
    r"project\s*\(\s*([^\s)]+)\s+VERSION\s+([^\s)]+)",
    cmake_text,
    re.MULTILINE,
)
if not match:
    raise SystemExit(f"could not parse project name/version from {cmake_file}")
name, version = match.group(1), match.group(2)

license_text = license_file.read_text(encoding="utf-8")
if "Apache License" in license_text and "Version 2.0" in license_text:
    license_id = "Apache-2.0"
else:
    license_id = "UNKNOWN"

url = "https://github.com/qdrddr/chunk-your-tools"
license_path = str(license_file.resolve())

row = {
    "Name": name,
    "Version": version,
    "License": license_id,
    "URL": url,
    "LicenseFile": license_path,
    "LicenseText": license_text,
    "RuntimeDependency": "chunk-your-tools (Rust FFI)",
    "RuntimeLicenseAudit": "scripts/legal/audit-rust.sh",
    "PackageManagerDependencies": [],
}

if do_check:
    if license_id == "UNKNOWN":
        raise SystemExit(f"c sdk/c: could not identify license from {license_file}")
    if license_id not in allowed:
        raise SystemExit(
            f"c sdk/c: license {license_id!r} is not in LEGAL_ALLOWED_LICENSES"
        )

if do_report:
    report_json.write_text(json.dumps([row], indent=2) + "\n", encoding="utf-8")

    lines = [
        "| Name | Version | License | URL | LicenseFile | RuntimeDependency |",
        "| --- | --- | --- | --- | --- | --- |",
        (
            f"| {name} | {version} | {license_id} | {url} | {license_path} | "
            f"{row['RuntimeDependency']} (see rust-deny-chunk-your-tools.txt) |"
        ),
        "",
        "Native runtime dependency licenses are audited by `audit-rust.sh`.",
        "The C SDK itself has no CMake/vcpkg/Conan package dependencies.",
    ]
    report_md.write_text("\n".join(lines) + "\n", encoding="utf-8")

print(f"{name} {version} {license_id}")
PY

if [[ "${DO_REPORT}" -eq 1 ]]; then
	legal_write_summary_line "c sdk/c: license metadata -> c-${slug}.{md,json}"
fi

if [[ "${DO_CHECK}" -eq 1 ]]; then
	legal_write_summary_line "c sdk/c: license within allow-list"
fi
