#!/usr/bin/env bash
# Build TypeScript native bindings via @napi-rs/cli with an explicit binary path.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
napi_bin="${ROOT}/sdk/typescript/node_modules/.bin/napi"
if [[ ! -x "${napi_bin}" ]]; then
	echo "error: missing ${napi_bin} (run: cd sdk/typescript && npm ci)" >&2
	exit 1
fi

cd "${ROOT}/sdk/typescript"
exec env -u npm_config_devdir CARGO_TARGET_DIR="${ROOT}/target" \
	"${napi_bin}" build --platform --release \
	--manifest-path ../../Cargo.toml \
	-p chunk-your-tools --features node --no-default-features \
	--output-dir . --js native.cjs --dts native.d.ts "$@"
