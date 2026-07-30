#!/usr/bin/env bash
# Back-compat wrapper — prefer ./scripts/publish/publish-pypi.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/publish/publish-pypi.sh" "$@"
