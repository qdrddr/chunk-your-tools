#!/usr/bin/env bash
# shellcheck shell=bash
# Shared helpers for chunk-your-tools local development.
# Not meant to be executed directly.

if [[ -z "${CHUNK_YOUR_TOOLS_LOCAL_DEV_LIB_SOURCED:-}" ]]; then
	# shellcheck source=scripts/local-dev-lib.sh
	source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/local-dev-lib.sh"
fi
