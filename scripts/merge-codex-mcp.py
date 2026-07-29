#!/usr/bin/env python3
"""Reconcile managed MCP sections in Codex config.toml without starting OAuth."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


SECTION = re.compile(r"^\[mcp_servers\.(?:\"([^\"]+)\"|([A-Za-z0-9_-]+))\]\s*$")


def strip_managed_sections(text: str, managed: set[str]) -> str:
    output: list[str] = []
    skipping = False
    for line in text.splitlines():
        if line.startswith("["):
            match = SECTION.fullmatch(line)
            skipping = bool(match and (match.group(1) or match.group(2)) in managed)
        if not skipping:
            output.append(line)
    return "\n".join(output).rstrip()


def render_section(name: str, item: dict[str, object]) -> str:
    lines = [f"[mcp_servers.{name}]"]
    if item["type"] == "http":
        lines.append(f"url = {json.dumps(item['url'])}")
    else:
        lines.append(f"command = {json.dumps(item['command'])}")
        args = ", ".join(json.dumps(value) for value in item.get("args", []))
        lines.append(f"args = [{args}]")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", required=True, type=Path)
    parser.add_argument("--catalog", required=True, type=Path)
    args = parser.parse_args()

    servers = json.loads(args.catalog.read_text())["mcpServers"]
    existing = args.target.read_text() if args.target.exists() else ""
    base = strip_managed_sections(existing, set(servers))
    managed = "\n\n".join(
        render_section(name, servers[name]) for name in sorted(servers)
    )
    content = f"{base}\n\n{managed}\n" if base else f"{managed}\n"

    args.target.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.target.with_name(f"{args.target.name}.tmp")
    temporary.write_text(content)
    temporary.replace(args.target)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
