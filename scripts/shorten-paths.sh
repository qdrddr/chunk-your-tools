#!/usr/bin/env bash
# Back-compat wrapper — prefer ./scripts/lib/shorten-paths.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/lib/shorten-paths.sh" "$@"
