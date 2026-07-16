"""Smoke tests for the editable chunk-your-tools Python SDK."""

from __future__ import annotations

from chunk_your_tools import build_catalog_from_tools, build_catalog_index


def _decomposed_metadata_types(index) -> dict[str, str]:
    meta = index.tool_schema_metadata()
    decomposed = meta.get("decomposed") or []
    return {
        entry["file_path"]: entry["type"]
        for entry in decomposed
        if isinstance(entry, dict) and "file_path" in entry and "type" in entry
    }


def test_build_catalog_index_from_tool() -> None:
    tool = {
        "id": "mcp__test__foo",
        "server": "test",
        "tool": "mcp__test__foo",
        "summary": "A test tool",
        "full_schema": {
            "id": "mcp__test__foo",
            "name": "mcp__test__foo",
            "description": "A test tool",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "required_field": {"type": "string"},
                    "optional_field": {"type": "string", "description": "opt"},
                },
                "required": ["required_field"],
            },
        },
    }
    index = build_catalog_index([tool], [])
    assert "schemas/decomposed/mcp__test__foo.json" in index.files


def test_build_catalog_from_anthropic_tool() -> None:
    tool = {
        "name": "Agent",
        "description": "Launch agents",
        "input_schema": {
            "type": "object",
            "properties": {
                "prompt": {"type": "string"},
                "model": {"type": "string", "enum": ["opus", "haiku"]},
            },
            "required": ["prompt"],
        },
    }
    index = build_catalog_from_tools([tool])
    assert "schemas/decomposed/Agent.json" in index.files
    assert any("Agent/model" in path for path in index.files)
    assert "schemas/decomposed/haiku.md" in index.files


def test_decomposed_metadata_entry_types() -> None:
    tool = {
        "name": "Agent",
        "description": "Launch agents",
        "input_schema": {
            "type": "object",
            "properties": {
                "prompt": {"type": "string"},
                "model": {"type": "string", "enum": ["opus", "haiku"]},
            },
            "required": ["prompt"],
        },
    }
    index = build_catalog_from_tools([tool])
    types = _decomposed_metadata_types(index)
    assert types["schemas/decomposed/Agent.json"] == "tool"
    assert types["schemas/decomposed/Agent/model.json"] == "property"
    assert types["schemas/decomposed/haiku.md"] == "enum"
    assert types["schemas/decomposed/opus.md"] == "enum"
