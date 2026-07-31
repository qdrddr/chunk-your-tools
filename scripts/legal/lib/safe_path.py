"""Resolve CLI paths under an allowed base directory."""

from __future__ import annotations

from pathlib import Path


def resolve_path(value: str | Path) -> Path:
    return Path(value).expanduser().resolve(strict=False)


def is_under(path: Path, base: Path) -> bool:
    try:
        path.relative_to(base)
        return True
    except ValueError:
        return False


def require_under(path: str | Path, base: Path, *, label: str) -> Path:
    resolved = resolve_path(path)
    base_resolved = resolve_path(base)
    if not is_under(resolved, base_resolved):
        raise SystemExit(f"{label} must stay under {base_resolved}, got {resolved}")
    return resolved


def require_repo_root(path: str | Path) -> Path:
    resolved = resolve_path(path)
    if not (resolved / "Cargo.toml").is_file():
        raise SystemExit(f"repo root not found: {resolved}")
    if not (resolved / "legal" / "policy.toml").is_file():
        raise SystemExit(f"legal policy not found under: {resolved}")
    return resolved
