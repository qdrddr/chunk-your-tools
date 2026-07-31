#!/usr/bin/env python3
"""Generate legal/ reference docs from audit output and legal/policy.toml."""

from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))

from policy import Policy, load_policy, normalize_license  # noqa: E402
from safe_path import require_repo_root, require_under  # noqa: E402


@dataclass(frozen=True)
class TrackedComponent:
    name: str
    version: str
    license: str
    dependency_path: str
    notice_url: str | None = None


def load_json_object(path: Path) -> object:
    text = path.read_text(encoding="utf-8")
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        decoder = json.JSONDecoder()
        obj, _ = decoder.raw_decode(text.lstrip())
        return obj


def rust_lookup(audit_dir: Path) -> dict[str, dict[str, str]]:
    path = audit_dir / "rust-license-chunk-your-tools.json"
    if not path.is_file():
        return {}
    rows = load_json_object(path)
    out: dict[str, dict[str, str]] = {}
    if isinstance(rows, list):
        for row in rows:
            name = str(row.get("name", "")).lower()
            if name:
                out[name] = {
                    "version": str(row.get("version", "")),
                    "license": str(row.get("license", "")),
                }
    return out


def npm_lookup(audit_dir: Path) -> dict[str, list[dict[str, str]]]:
    out: dict[str, list[dict[str, str]]] = {}
    for path in sorted(audit_dir.glob("npm-*.json")):
        if path.name.endswith("-summary.txt"):
            continue
        data = load_json_object(path)
        if not isinstance(data, dict):
            continue
        for key, row in data.items():
            pkg, _, version = key.partition("@")
            if not version:
                continue
            name = pkg.lower()
            out.setdefault(name, []).append(
                {
                    "version": version,
                    "license": str(row.get("licenses", "")),
                    "path": _npm_dependency_path(path, pkg, str(row.get("path", ""))),
                },
            )
    return out


def _npm_dependency_path(report: Path, pkg: str, install_path: str) -> str:
    if report.name == "npm-..json":
        return "repo root dependency"
    if "/@napi-rs/cli/node_modules/" in install_path:
        return f"@napi-rs/cli -> {pkg}"
    if pkg == "js-yaml":
        return "@napi-rs/cli -> js-yaml"
    if pkg == "argparse":
        return "@napi-rs/cli -> js-yaml -> argparse"
    if report.name == "npm-sdk-typescript.json":
        return "sdk/typescript devDependency"
    return "dev dependency tree"


def read_project_version(repo_root: Path) -> str:
    cargo = repo_root / "Cargo.toml"
    match = re.search(r'^version\s*=\s*"(.+)"', cargo.read_text(encoding="utf-8"), re.M)
    return match.group(1) if match else "unknown"


def build_tracked_components(
    repo_root: Path, audit_dir: Path, policy: Policy,
) -> list[TrackedComponent]:
    rust = rust_lookup(audit_dir)
    npm = npm_lookup(audit_dir)
    version = read_project_version(repo_root)
    tracked: list[TrackedComponent] = [
        TrackedComponent(
            name=policy.project_name,
            version=version,
            license=policy.project_license,
            dependency_path=f"{policy.project_name} ({policy.project_copyright})",
        ),
    ]

    for spec in policy.tracked_components:
        if spec.kind.startswith("rust"):
            row = rust.get(spec.name)
            if not row:
                continue
            tracked.append(
                TrackedComponent(
                    name=spec.name,
                    version=row["version"],
                    license=row["license"],
                    dependency_path=spec.dependency_path or spec.kind,
                ),
            )
            continue

        seen: set[tuple[str, str, str]] = set()
        for row in npm.get(spec.name, []):
            key = (row["version"], row["license"], row["path"])
            if key in seen:
                continue
            seen.add(key)
            tracked.append(
                TrackedComponent(
                    name=spec.name,
                    version=row["version"],
                    license=row["license"],
                    dependency_path=spec.dependency_path or row["path"],
                    notice_url=spec.notice_url,
                ),
            )

    return tracked


def group_by_obligation(
    components: list[TrackedComponent], policy: Policy,
) -> dict[str, dict[str, list[TrackedComponent]]]:
    grouped: dict[str, dict[str, list[TrackedComponent]]] = {
        key: {} for key in policy.obligation_types
    }
    for component in components:
        for obligation in policy.obligations_for_license(component.license):
            if obligation == "include-notice":
                if component.notice_url is None and component.name != policy.project_name:
                    continue
            license_key = " and ".join(
                sorted(normalize_license(component.license, policy.aliases)),
            )
            grouped[obligation].setdefault(license_key, []).append(component)
    return grouped


def format_obligation_file(
    obligation: str, license_groups: dict[str, list[TrackedComponent]], policy: Policy,
) -> str:
    meta = policy.obligation_types[obligation]
    lines = [meta.title, "", meta.description, ""]
    if not license_groups:
        lines.append("(No tracked components require this obligation at audit time.)")
        lines.append("")
        return "\n".join(lines)

    for license_label in sorted(license_groups):
        lines.append(f"License: {license_label}")
        lines.append("")
        if obligation == "include-copyright":
            lines.append(
                "You must include the copyright notice in all copies or substantial uses of the work.",
            )
            lines.append("")
        elif obligation == "include-licenses":
            lines.append(
                "You must include the license notice in all copies or substantial uses of the work.",
            )
            lines.append("")

        lines.append("Component | Version | Dependency path")
        for component in sorted(
            license_groups[license_label],
            key=lambda c: (c.name, c.version, c.dependency_path),
        ):
            if component.name == policy.project_name and obligation == "include-licenses":
                detail = f"{policy.project_name} ({policy.project_license}; see LICENSE)"
            elif component.name == policy.project_name and obligation == "include-notice":
                detail = f"{policy.project_name} (see ../NOTICE)"
            else:
                detail = component.dependency_path
            lines.append(f"{component.name} | {component.version} | {detail}")
        lines.append("")

    if obligation == "include-notice":
        urls = sorted(
            {c.notice_url for group in license_groups.values() for c in group if c.notice_url},
        )
        if urls:
            lines.append("Third-party NOTICE sources:")
            lines.append("")
            for url in urls:
                lines.append(f"- {url}")

    return "\n".join(lines).rstrip() + "\n"


def write_license_compatibility(legal_dir: Path, policy: Policy) -> None:
    lines = [
        "License Compatibility Summary",
        "",
        "Generated from legal/policy.toml. Edit that file, then re-run:",
        "  ./scripts/legal/audit-all.sh --with-dev",
        "",
        "The following table summarizes licenses tracked by project policy and their",
        "compatibility with this Apache 2.0 project.",
        "",
        "License | Permissive for Business Use? | Compatible with Apache 2.0? | Notes",
    ]
    for spdx, business, compatible, notes in policy.compatibility_rows():
        lines.append(f"{spdx} | {business} | {compatible} | {notes}")
    lines.append("")
    (legal_dir / "license-compatibility.txt").write_text("\n".join(lines), encoding="utf-8")


def write_obligations(
    legal_dir: Path, components: list[TrackedComponent], policy: Policy,
) -> None:
    obligations_dir = legal_dir / "obligations"
    obligations_dir.mkdir(parents=True, exist_ok=True)
    grouped = group_by_obligation(components, policy)
    for obligation in policy.obligation_types:
        content = format_obligation_file(obligation, grouped[obligation], policy)
        (obligations_dir / f"{obligation}.txt").write_text(content, encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 3:
        print(
            f"usage: {Path(sys.argv[0]).name} REPO_ROOT AUDIT_OUTPUT_DIR",
            file=sys.stderr,
        )
        return 2

    repo_root = require_repo_root(sys.argv[1])
    audit_dir = require_under(sys.argv[2], repo_root, label="audit dir")
    legal_dir = repo_root / "legal"

    if not audit_dir.is_dir():
        print(f"error: audit output dir not found: {audit_dir}", file=sys.stderr)
        return 1

    policy = load_policy(str(repo_root))
    legal_dir.mkdir(parents=True, exist_ok=True)
    components = build_tracked_components(repo_root, audit_dir, policy)
    write_license_compatibility(legal_dir, policy)
    write_obligations(legal_dir, components, policy)
    print(f"updated {legal_dir.relative_to(repo_root)}/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
