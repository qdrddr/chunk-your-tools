#!/usr/bin/env bash
# Sync deny.toml [licenses].allow from legal/policy.toml (single source of truth).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/legal/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

legal_require_repo_root
legal_require_cmd python3
python3 "${SCRIPT_DIR}/lib/policy.py" sync-deny "${LEGAL_REPO_ROOT}"
