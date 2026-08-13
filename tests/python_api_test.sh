#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/macos-python-coverage.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
export PYTHONDONTWRITEBYTECODE=1

TRACE_DATA="${TEST_ROOT}/counts.dat"
TRACE_DIR="${TEST_ROOT}/report"
if python3 -m trace --count --missing --file="$TRACE_DATA" --coverdir="$TRACE_DIR" \
  "${ROOT}/tests/python_api_cases.py" >"${TEST_ROOT}/trace.log" 2>&1; then
  printf '%s\n' 'ok - Python helpers pass deterministic API and CLI cases'
else
  cat "${TEST_ROOT}/trace.log" >&2
  printf '%s\n' 'not ok - Python helpers pass deterministic API and CLI cases' >&2
  exit 1
fi

for module_name in discover-skills merge-mcp merge-codex-mcp; do
  report="$(find "$TRACE_DIR" -type f -name "*.${module_name}.cover" -print -quit)"
  if [[ ! -f "$report" ]]; then
    printf 'not ok - coverage report exists for %s\n' "$module_name" >&2
    exit 1
  fi
  if grep -q '^>>>>>>' "$report"; then
    printf 'not ok - %s has uncovered executable lines\n' "$module_name" >&2
    grep '^>>>>>>' "$report" >&2
    exit 1
  fi
  printf 'ok - %s executable line coverage is 100%%\n' "$module_name"
done
