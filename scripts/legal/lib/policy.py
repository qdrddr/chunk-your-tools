#!/usr/bin/env python3
"""Load legal/policy.toml — single source of truth for license policy."""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - py3.10
    import tomli as tomllib  # type: ignore[no-redef]

from safe_path import require_repo_root


@dataclass(frozen=True)
class LicensePolicy:
    spdx: str
    allow: bool
    business_use: str
    apache_compatible: str
    notes: str
    obligations: tuple[str, ...]
    requires_notice_file: bool = False


@dataclass(frozen=True)
class ObligationType:
    id: str
    title: str
    description: str


@dataclass(frozen=True)
class TrackedComponentSpec:
    name: str
    kind: str
    dependency_path: str | None = None
    notice_url: str | None = None


@dataclass(frozen=True)
class Policy:
    path: Path
    project_name: str
    project_license: str
    project_copyright: str
    obligation_types: dict[str, ObligationType]
    licenses: dict[str, LicensePolicy]
    aliases: dict[str, str]
    tracked_components: tuple[TrackedComponentSpec, ...]

    def allowed_spdx_ids(self) -> list[str]:
        return [entry.spdx for entry in self.licenses.values() if entry.allow]

    def allowed_csv(self) -> str:
        return ";".join(self.allowed_spdx_ids())

    def license_allowed(self, raw: str) -> bool:
        for token in normalize_license(raw, self.aliases):
            entry = self.licenses.get(token)
            if entry is None or not entry.allow:
                return False
        return True

    def compatibility_rows(self) -> list[tuple[str, str, str, str]]:
        rows: list[tuple[str, str, str, str]] = []
        for spdx in self.allowed_spdx_ids():
            entry = self.licenses[spdx]
            rows.append((entry.spdx, entry.business_use, entry.apache_compatible, entry.notes))
        for entry in self.licenses.values():
            if entry.allow:
                continue
            rows.append((entry.spdx, entry.business_use, entry.apache_compatible, entry.notes))
        return rows

    def obligations_for_license(self, raw: str) -> set[str]:
        found: set[str] = set()
        for token in normalize_license(raw, self.aliases):
            entry = self.licenses.get(token)
            if entry:
                found.update(entry.obligations)
        return found


def repo_root_from_here() -> Path:
    here = Path(__file__).resolve()
    return here.parents[3]


def policy_path(repo_root: Path | None = None) -> Path:
    root = repo_root or repo_root_from_here()
    return root / "legal" / "policy.toml"


@lru_cache(maxsize=4)
def load_policy(repo_root: str | None = None) -> Policy:
    root = Path(repo_root).resolve() if repo_root else repo_root_from_here()
    path = policy_path(root)
    with path.open("rb") as handle:
        data = tomllib.load(handle)

    project = data.get("project", {})
    obligation_types = {
        row["id"]: ObligationType(
            id=row["id"],
            title=row["title"],
            description=row["description"].strip(),
        )
        for row in data.get("obligation_types", [])
    }
    licenses = {
        row["spdx"]: LicensePolicy(
            spdx=row["spdx"],
            allow=bool(row.get("allow", False)),
            business_use=str(row.get("business_use", "Review required")),
            apache_compatible=str(row.get("apache_compatible", "Review required")),
            notes=str(row.get("notes", "")),
            obligations=tuple(row.get("obligations", [])),
            requires_notice_file=bool(row.get("requires_notice_file", False)),
        )
        for row in data.get("licenses", [])
    }
    aliases = {str(k): str(v) for k, v in data.get("aliases", {}).items()}
    tracked = tuple(
        TrackedComponentSpec(
            name=row["name"],
            kind=row["kind"],
            dependency_path=row.get("dependency_path"),
            notice_url=row.get("notice_url"),
        )
        for row in data.get("tracked_components", [])
    )
    return Policy(
        path=path,
        project_name=str(project.get("name", "")),
        project_license=str(project.get("license", "")),
        project_copyright=str(project.get("copyright", "")),
        obligation_types=obligation_types,
        licenses=licenses,
        aliases=aliases,
        tracked_components=tracked,
    )


def normalize_license(raw: str, aliases: dict[str, str] | None = None) -> set[str]:
    alias_map = aliases or load_policy().aliases
    parts = re.split(r"\s+(?:OR|AND)\s+", raw.strip(), flags=re.IGNORECASE)
    normalized: set[str] = set()
    for part in parts:
        token = part.strip()
        token = alias_map.get(token, token)
        normalized.add(token)
    return normalized


def render_deny_toml_licenses_allow(policy: Policy) -> str:
    lines = ['allow = [']
    for spdx in policy.allowed_spdx_ids():
        lines.append(f'    "{spdx}",')
    lines.append("]")
    return "\n".join(lines)


def sync_deny_toml(repo_root: Path, policy: Policy | None = None) -> bool:
    policy = policy or load_policy(str(repo_root))
    deny_path = repo_root / "deny.toml"
    text = deny_path.read_text(encoding="utf-8")
    replacement = render_deny_toml_licenses_allow(policy)
    updated, count = re.subn(
        r"allow\s*=\s*\[[^\]]*\]",
        replacement,
        text,
        count=1,
        flags=re.S,
    )
    if count != 1:
        raise RuntimeError(f"could not update [licenses].allow in {deny_path}")
    if updated != text:
        deny_path.write_text(updated, encoding="utf-8")
        return True
    return False


def main(argv: list[str] | None = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    if not args:
        print("usage: policy.py allowed-csv|allowed SPDX|sync-deny [REPO_ROOT]", file=sys.stderr)
        return 2

    command = args[0]
    repo_root = args[1] if len(args) > 1 and command in {"sync-deny"} else None
    if len(args) > 1 and command == "allowed":
        license_arg = args[1]
    else:
        license_arg = None

    policy = load_policy(repo_root)

    if command == "allowed-csv":
        print(policy.allowed_csv())
        return 0
    if command == "allowed":
        if not license_arg:
            print("usage: policy.py allowed SPDX", file=sys.stderr)
            return 2
        return 0 if policy.license_allowed(license_arg) else 1
    if command == "sync-deny":
        root = require_repo_root(repo_root) if repo_root else repo_root_from_here()
        changed = sync_deny_toml(root, policy)
        print("updated deny.toml" if changed else "deny.toml already in sync")
        return 0

    print(f"unknown command: {command}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
