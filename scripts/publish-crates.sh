#!/usr/bin/env bash
# Back-compat wrapper — prefer ./scripts/publish/publish-crates.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/publish/publish-crates.sh" "$@"
