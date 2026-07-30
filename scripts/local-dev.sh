#!/usr/bin/env bash
# Back-compat wrapper — prefer ./scripts/local/dev/workflow.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/local/dev/workflow.sh" "$@"
