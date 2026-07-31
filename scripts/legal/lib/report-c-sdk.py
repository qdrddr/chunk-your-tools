#!/usr/bin/env python3
"""Write first-party license reports for sdk/c (FFI headers + prebuilt releases)."""

from __future__ import annotations

import json
import sys
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover
    import tomli as tomllib  # type: ignore[no-redef]

from safe_path import require_repo_root, require_under


def load_toml(path: Path) -> dict:
    with path.open("rb") as handle:
        return tomllib.load(handle)


def cargo_package(repo_root: Path) -> dict[str, str]:
    cargo = repo_root / "Cargo.toml"
    data = load_toml(cargo)
    package = data.get("package")
    if not isinstance(package, dict):
        return {}
    out: dict[str, str] = {}
    for key in ("name", "version", "license", "repository"):
        value = package.get(key)
        if isinstance(value, str) and value:
            out[key] = value
    return out


def resolve_license_file(sdk_dir: Path) -> Path | None:
    for name in ("LICENSE", "LICENSE.md", "LICENSE.txt", "COPYING"):
        candidate = sdk_dir / name
        if candidate.is_file():
            return candidate
    return None


def resolve_url(*, repository: str | None, sdk_dir: Path, repo_root: Path) -> str:
    if repository:
        try:
            rel = sdk_dir.relative_to(repo_root).as_posix()
        except ValueError:
            rel = sdk_dir.name
        base = repository.rstrip("/")
        if base.endswith(".git"):
            base = base[:-4]
        return f"{base}/tree/main/{rel}"
    return sdk_dir.resolve().as_uri()


def rows_to_markdown(rows: list[dict]) -> str:
    headers = [
        "Name",
        "Component",
        "Version",
        "License",
        "URL",
        "LicenseFile",
        "Notes",
    ]

    def cell(row: dict, header: str) -> str:
        return str(row.get(header, "") or "").replace("|", "\\|")

    lines = [
        "| " + " | ".join(headers) + " |",
        "|" + "|".join("---" for _ in headers) + "|",
    ]
    for row in rows:
        lines.append("| " + " | ".join(cell(row, header) for header in headers) + " |")
    return "\n".join(lines) + "\n"


def build_report(*, repo_root: Path, sdk_dir: Path) -> list[dict]:
    package = cargo_package(repo_root)
    license_file = resolve_license_file(sdk_dir)
    repository = package.get("repository")
    return [
        {
            "Name": package.get("name", "chunk-your-tools"),
            "Component": "C SDK (FFI)",
            "Version": package.get("version", "unknown"),
            "License": package.get("license", "Apache-2.0"),
            "URL": resolve_url(
                repository=repository,
                sdk_dir=sdk_dir,
                repo_root=repo_root,
            ),
            "LicenseFile": str(license_file.resolve()) if license_file else "UNKNOWN",
            "Notes": "Transitive native dependencies are audited in the rust step (cargo-deny).",
        },
    ]


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(
            "usage: report-c-sdk.py REPO_ROOT OUTPUT_DIR",
            file=sys.stderr,
        )
        return 2

    repo_root = require_repo_root(argv[1])
    output_dir = require_under(argv[2], repo_root, label="output dir")
    sdk_dir = repo_root / "sdk" / "c"

    if not sdk_dir.is_dir():
        print(f"missing sdk dir: {sdk_dir}", file=sys.stderr)
        return 1

    rows = build_report(repo_root=repo_root, sdk_dir=sdk_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    json_path = output_dir / "c-sdk.json"
    md_path = output_dir / "c-sdk.md"
    json_path.write_text(json.dumps(rows, indent=2) + "\n", encoding="utf-8")
    md_path.write_text(rows_to_markdown(rows), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
