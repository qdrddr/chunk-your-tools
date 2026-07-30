#!/usr/bin/env bash
# Back-compat wrapper — prefer ./scripts/pre-commit-hooks/trufflehog-hook.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/pre-commit-hooks/trufflehog-hook.sh" "$@"
