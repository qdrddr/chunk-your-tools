#!/usr/bin/env bash
# Back-compat wrapper — prefer scripts/local/dev/helpers.sh (source, do not execute).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/local/dev/helpers.sh"
