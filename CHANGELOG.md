# Changelog

All notable changes to [chunk-your-tools](https://github.com/qdrddr/chunk-your-tools) are
documented here. Version numbers follow [Cargo.toml](Cargo.toml) and are propagated to Python,
TypeScript, Go, and C SDKs via `./scripts/sync-version.sh`.

## 1.0.6

- Dedicated E2E workflows for crates.io, npm, and PyPI published packages
- README and examples documentation updates

## 1.0.5

- Shared `_repo_root.sh` for example scripts to resolve the monorepo root reliably

## 1.0.4

- Example `decompose` / `recompose` scripts and catalog output paths
- C SDK compile-database fix for clang-tidy in local dev

## 1.0.3

- Version sync across Rust, Python, TypeScript, Go, and C packages

## 1.0.2

- CI workflow improvements; normalized path separators in Rust catalog paths

## 1.0.1

- Publish scripts for crates.io, npm, and PyPI
- SDK naming alignment across language bindings

## 1.0.0

### Includes

- Rust library and `chunk-your-tools` CLI (`decompose`, `recompose`)
- Python, TypeScript, Go (cgo), and C FFI SDKs
- Semantic survivor format (`tools`, `properties`, `enums`)
