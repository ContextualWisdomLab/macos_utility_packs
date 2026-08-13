#!/usr/bin/env python3
"""Merge owned MCP entries into a client JSON configuration."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    """Parse target, catalog, section, and client-format command-line options."""

    parser = argparse.ArgumentParser()
    parser.add_argument("--target", required=True, type=Path)
    parser.add_argument("--catalog", required=True, type=Path)
    parser.add_argument("--section", required=True)
    parser.add_argument(
        "--format", choices=("generic", "vscode", "antigravity"), default="generic"
    )
    return parser.parse_args()


def vscode_entry(entry: dict[str, Any]) -> dict[str, Any]:
    """Return a copy of an MCP entry in VS Code's server shape."""

    converted = dict(entry)
    if converted.get("type") == "http":
        converted["type"] = "http"
    return converted


def antigravity_entry(entry: dict[str, Any]) -> dict[str, Any]:
    """Convert a generic MCP entry to Antigravity's serverUrl shape."""

    converted = dict(entry)
    converted.pop("type", None)
    url = converted.pop("url", None)
    if url:
        converted["serverUrl"] = url
    return converted


def load_json(path: Path) -> dict[str, Any]:
    """Load a JSON object, treating a missing or empty file as empty state."""

    if not path.exists() or not path.read_text().strip():
        return {}
    payload = json.loads(path.read_text())
    if not isinstance(payload, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return payload


def main() -> int:
    """Merge catalog entries into a client JSON file with atomic replacement."""

    args = parse_args()
    target = load_json(args.target)
    catalog = load_json(args.catalog).get("mcpServers", {})
    if not isinstance(catalog, dict):
        raise ValueError("catalog mcpServers must be an object")
    section = target.setdefault(args.section, {})
    if not isinstance(section, dict):
        raise ValueError(f"target section {args.section} must be an object")
    for name, entry in catalog.items():
        if args.format == "vscode":
            section[name] = vscode_entry(entry)
        elif args.format == "antigravity":
            section[name] = antigravity_entry(entry)
        else:
            section[name] = entry

    args.target.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.target.with_name(f".{args.target.name}.tmp.{os.getpid()}")
    temporary.write_text(json.dumps(target, indent=2, sort_keys=True) + "\n")
    temporary.replace(args.target)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
