#!/usr/bin/env bash
# Back-compat wrapper — prefer ./scripts/local/tests/all-fallow.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/local/tests/all-fallow.sh" "$@"
