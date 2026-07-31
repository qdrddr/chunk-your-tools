#!/usr/bin/env bash
# Install pinned gosec for CI. Not tracked in any go.mod — keeps Snyk surface minimal.
#
# Usage:
#   ./scripts/deps/ensure-go-gosec.sh
#   GOSEC_VERSION=v2.28.0 ./scripts/deps/ensure-go-gosec.sh
#
# Typical CI:
#   ./scripts/deps/ensure-go-gosec.sh
#   bash scripts/pre-commit-hooks/go-sdk-precommit.sh sec

set -euo pipefail

GOSEC_VERSION="${GOSEC_VERSION:-v2.28.0}"

if command -v rtk >/dev/null 2>&1; then
	rtk go install "github.com/securego/gosec/v2/cmd/gosec@${GOSEC_VERSION}"
else
	go install "github.com/securego/gosec/v2/cmd/gosec@${GOSEC_VERSION}"
fi

gosec_bin="$(go env GOPATH)/bin/gosec"
[[ -x "${gosec_bin}" ]] || {
	echo "error: gosec not installed at ${gosec_bin}" >&2
	exit 1
}

printf 'gosec ready: %s (%s)\n' "${gosec_bin}" "${GOSEC_VERSION}"
