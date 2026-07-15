#!/usr/bin/env bash
# update pyproject.toml version first

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT
version="$(
	grep -E '^version[[:space:]]*=' "${ROOT}/pyproject.toml" |
		head -1 |
		sed -E 's/^version[[:space:]]*=[[:space:]]*"(.*)".*/\1/'
)"
export version
export tag="v${version}"

oco -n
git checkout main
git pull origin main
git tag "${tag}"
git push origin "${tag}"

git tag "sdk/go/v${version}"
git push origin "sdk/go/v${version}"

cargo test -p chunk-your-tools
cargo publish --dry-run
CARGO_REGISTRY_TOKEN="$(security find-generic-password -s "cyt" -a "CARGO_REGISTRY_TOKEN" -w)"
export CARGO_REGISTRY_TOKEN
# cargo login

# Verify before publishing
cargo package --list | grep assets # should show nothing
cargo package --list | wc -l       # should be much smaller than 297
cargo package                      # check compressed size

cargo publish --allow-dirty

# bash scripts/sync-version.sh
# export CARGO_REGISTRY_TOKEN="$(security find-generic-password -s "cyt" -a "CARGO_REGISTRY_TOKEN" -w)"
# cargo build -p chunk-your-tools
# cargo test -p chunk-your-tools
# cargo publish -p chunk-your-tools --dry-run
# cargo publish
# gh workflow run publish-crates.yml --ref rust -f version=0.1.0

# npm login
# npm whoami
# npm view chunk-your-tools
# cd sdk/typescript
# npm version 0.1.4 --no-git-tag-version
# npm ci
# npm test

# one-time:
npm login
npm whoami

cd sdk/typescript || exit
npm ci
npm run build:js
# Release publishes all platforms via publish-npm-sdk.yml (single fat package).
# Manual publish is only for bootstrapping or emergencies; you need every
# chunk-your-tools.*.node in this directory before npm publish.
npm publish --access public
