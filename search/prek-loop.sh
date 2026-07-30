#!/usr/bin/env bash
# Run prek hooks one at a time until all pass. Prefer scripts/pre-commit-hooks/prek-loop.sh.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/../scripts/pre-commit-hooks/prek-loop.sh" "$@"
