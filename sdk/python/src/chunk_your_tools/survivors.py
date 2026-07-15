"""Named survivor mapping and tool recomposition helpers."""

from __future__ import annotations

from typing import Any

from chunk_your_tools._native import (
    recompose_tools_from_names as _recompose_tools_from_names,
)
from chunk_your_tools._native import (
    resolve_survivors_from_names as _resolve_survivors_from_names,
)

__all__ = ["recompose_tools_from_names", "resolve_survivors_from_names"]


def resolve_survivors_from_names(index: Any, survivors: Any) -> Any:
    """Map named survivor tool/property/enum lists to catalog survivor data."""
    return _resolve_survivors_from_names(index, survivors)


def recompose_tools_from_names(
    tools: Any,
    survivors: Any,
    policy_context: Any | None = None,
) -> Any:
    """Recompose pruned tool schemas from named survivors."""
    if policy_context is None:
        return _recompose_tools_from_names(tools, survivors, None)
    return _recompose_tools_from_names(tools, survivors, policy_context)
