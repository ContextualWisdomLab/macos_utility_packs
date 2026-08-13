#!/usr/bin/env bash

set -u

if [[ "${RUN_LIVE_TESTS:-0}" != "1" ]]; then
  printf '%s\n' 'ok - live host checks skipped (set RUN_LIVE_TESTS=1 to run)'
  exit 0
fi

failures=0
if ! command -v brew >/dev/null 2>&1; then
  printf '%s\n' 'not ok - Homebrew is available for live host checks' >&2
  failures=$((failures + 1))
fi
if ! command -v colima >/dev/null 2>&1; then
  printf '%s\n' 'not ok - Colima is available for live host checks' >&2
  failures=$((failures + 1))
fi
if ! command -v nerdctl >/dev/null 2>&1; then
  printf '%s\n' 'not ok - nerdctl is available for live host checks' >&2
  failures=$((failures + 1))
fi

if (( failures == 0 )); then
  if brew services list | awk '$1 == "colima" && $2 == "started"' | grep -q .; then
    printf '%s\n' 'ok - Colima is registered and started as a Homebrew service'
  else
    printf '%s\n' 'not ok - Colima is registered and started as a Homebrew service' >&2
    failures=$((failures + 1))
  fi
  runtime="$(colima status --json 2>/dev/null | python3 -c 'import json, sys; print(json.load(sys.stdin).get("runtime", ""))')" || runtime=""
  if [[ "$runtime" == "containerd" ]]; then
    printf '%s\n' 'ok - active Colima runtime is containerd'
  else
    printf 'not ok - active Colima runtime is containerd (found %s)\n' "${runtime:-unavailable}" >&2
    failures=$((failures + 1))
  fi
  if nerdctl info >/dev/null 2>&1; then
    printf '%s\n' 'ok - nerdctl can inspect the live container runtime'
  else
    printf '%s\n' 'not ok - nerdctl can inspect the live container runtime' >&2
    failures=$((failures + 1))
  fi
fi

if (( failures > 0 )); then
  exit 1
fi
