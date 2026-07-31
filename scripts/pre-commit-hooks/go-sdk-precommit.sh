#!/usr/bin/env bash
# Run Go SDK pre-commit tools scoped to sdk/go.
#
# Dev tools use pinned `go run ...@version` (local) or `go install` (gosec in CI)
# so nothing lands in go.mod — minimal Snyk surface on the runtime module.
#
# Usage:
#   go-sdk-precommit.sh fumpt|imports|tidy|staticcheck|critic|sec|build|test [files...]
#   go-sdk-precommit.sh fmt|lint|check
#
# Aggregates (prek-loop / local dev):
#   fmt   — gofumpt + goimports
#   lint  — staticcheck + gocritic
#   check — tidy + fmt + lint + sec
set -euo pipefail

ROOT="$(cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && pwd -P)"
GO_DIR="${ROOT}/sdk/go"

GOFUMPT_VERSION="${GOFUMPT_VERSION:-v0.11.0}"
GOIMPORTS_VERSION="${GOIMPORTS_VERSION:-v0.48.0}"
STATICCHECK_VERSION="${STATICCHECK_VERSION:-v0.7.0}"
GOCRITIC_VERSION="${GOCRITIC_VERSION:-v0.14.4}"
GOSEC_VERSION="${GOSEC_VERSION:-v2.28.0}"

cd "$GO_DIR"
export CGO_ENABLED=1
host_triplet="$(rustc -vV | sed -n 's/^host: //p')"
export PATH="${ROOT}/target/${host_triplet}/release:${PATH}"

run_go() {
	if command -v rtk >/dev/null 2>&1; then
		rtk go "$@"
	else
		go "$@"
	fi
}

rel_paths() {
	local out=()
	local f
	for f in "$@"; do
		out+=("${f#sdk/go/}")
	done
	printf '%s\n' "${out[@]}"
}

all_go_files() {
	find . -name '*.go' ! -path './vendor/*' | sort
}

resolve_go_files() {
	if (($#)); then
		rel_paths "$@"
	else
		all_go_files
	fi
}

gosec_bin() {
	printf '%s/bin/gosec' "$(run_go env GOPATH)"
}

run_gofumpt() {
	local -a files=()
	mapfile -t files < <(resolve_go_files "$@")
	if ((${#files[@]})); then
		run_go run "mvdan.cc/gofumpt@${GOFUMPT_VERSION}" -l -w "${files[@]}"
	fi
}

run_goimports() {
	local -a files=()
	mapfile -t files < <(resolve_go_files "$@")
	if ((${#files[@]})); then
		run_go run "golang.org/x/tools/cmd/goimports@${GOIMPORTS_VERSION}" -w "${files[@]}"
	fi
}

run_staticcheck() {
	run_go run "honnef.co/go/tools/cmd/staticcheck@${STATICCHECK_VERSION}" ./...
}

run_gocritic() {
	if (($#)); then
		local f
		for f in $(resolve_go_files "$@"); do
			run_go run "github.com/go-critic/go-critic/cmd/gocritic@${GOCRITIC_VERSION}" check "./${f}"
		done
	else
		run_go run "github.com/go-critic/go-critic/cmd/gocritic@${GOCRITIC_VERSION}" check ./...
	fi
}

run_gosec() {
	local pkg="github.com/securego/gosec/v2/cmd/gosec@${GOSEC_VERSION}"
	if [[ -n "${CI:-}" ]]; then
		run_go install "${pkg}"
		"$(gosec_bin)" ./...
		return
	fi
	run_go run "${pkg}" ./...
}

run_tidy() {
	run_go mod tidy
}

run_fmt() {
	run_gofumpt "$@"
	run_goimports "$@"
}

run_lint() {
	run_staticcheck
	run_gocritic "$@"
}

run_check() {
	run_tidy
	run_fmt "$@"
	run_lint "$@"
	run_gosec
}

tool=${1:?usage: go-sdk-precommit.sh TOOL [args...]}
shift

case "$tool" in
fumpt)
	run_gofumpt "$@"
	;;
imports)
	run_goimports "$@"
	;;
tidy)
	run_tidy
	;;
staticcheck)
	run_staticcheck
	;;
critic)
	run_gocritic "$@"
	;;
sec)
	run_gosec
	;;
fmt)
	run_fmt "$@"
	;;
lint)
	run_lint "$@"
	;;
check)
	run_check "$@"
	;;
build)
	run_go build ./...
	;;
test)
	env -u CARGO_TARGET_DIR "${ROOT}/sdk/c/scripts/build-c-lib.sh" --no-sync-header
	run_go run ./cmd/chunk-native-ensure -static-only
	(
		unset CARGO_TARGET_DIR
		run_go test ./...
	)
	;;
*)
	echo "unknown tool: $tool" >&2
	exit 1
	;;
esac
