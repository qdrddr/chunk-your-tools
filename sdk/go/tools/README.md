# Go SDK dev tools

Dev-only linters and scanners for [sdk/go](../). Kept in a separate module so Snyk and license audits on the
published runtime module (`sdk/go/go.mod`) stay limited to CGO + stdlib.

Pre-commit invokes these via [scripts/pre-commit-hooks/go-sdk-precommit.sh](../../../scripts/pre-commit-hooks/go-sdk-precommit.sh).

Manual usage from `sdk/go`:

```bash
staticcheck_bin="$(go -C tools tool -n staticcheck)"
"$staticcheck_bin" ./...

gosec_bin="$(go -C tools tool -n gosec)"
"$gosec_bin" ./...

go -C tools tool gofumpt -l -w ./...
```

## Pinned transitive versions

[pins.go](pins.go) keeps patched versions in `go.mod` for known advisories (grpc, AWS eventstream, MCP SDK,
JWT, goldmark). Re-run `go mod tidy` after changing pins.

Current security pins: `eventstream v1.7.15` (eventstream decoder CWE-248), `jwt/v5 v5.3.1`
(CVE-2024-51744), plus grpc, MCP SDK, and goldmark as listed in `go.mod`.
