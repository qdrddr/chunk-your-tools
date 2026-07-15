"""Smoke test for token counting from the published PyPI package."""

from __future__ import annotations

from chunk_your_tools import count_tokens


def test_count_tokens_smoke() -> None:
    assert count_tokens("hello world") >= 1
