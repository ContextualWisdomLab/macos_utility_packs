#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "${ROOT}/scripts/discover-skills.py" <<'PY'
"""Require beginner-readable docstrings for every public Python API."""

import ast
from pathlib import Path
import sys

source_path = Path(sys.argv[1])
tree = ast.parse(source_path.read_text(), filename=str(source_path))
missing = []

if ast.get_docstring(tree) is None:
    missing.append("module")

for node in tree.body:
    if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and not node.name.startswith("_"):
        if ast.get_docstring(node) is None:
            missing.append(f"function {node.name}")
    elif isinstance(node, ast.ClassDef) and not node.name.startswith("_"):
        if ast.get_docstring(node) is None:
            missing.append(f"class {node.name}")
        for member in node.body:
            if isinstance(member, (ast.FunctionDef, ast.AsyncFunctionDef)) and not member.name.startswith("_"):
                if ast.get_docstring(member) is None:
                    missing.append(f"method {node.name}.{member.name}")

if missing:
    print("missing public docstrings:", ", ".join(missing), file=sys.stderr)
    raise SystemExit(1)
PY
