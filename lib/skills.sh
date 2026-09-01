#!/usr/bin/env bash

# Keep exact matches so useful names such as mcp-builder remain installable.
SKILL_COMMAND_CONFLICT_NAMES=(mcp claude codex grok build)

skill_conflicts_with_client_command() {
  local candidate
  local name
  candidate="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  for name in "${SKILL_COMMAND_CONFLICT_NAMES[@]}"; do
    [[ "$candidate" == "$name" ]] && return 0
  done
  return 1
}

# Blocked shared-skill names live in config/skill-blacklist.json so operators can
# extend the deny list without touching sync logic. Matching is exact and
# Unicode-case-insensitive; cross-script homoglyph variants still require an
# explicit deny-list entry because case folding does not normalize lookalikes.
SKILL_BLACKLIST_FILE="${SKILL_BLACKLIST_FILE:-}"

skill_blacklist_file() {
  # Print the active deny-list path, honouring a test override when present.
  if [[ -n "$SKILL_BLACKLIST_FILE" ]]; then
    printf '%s\n' "$SKILL_BLACKLIST_FILE"
    return 0
  fi
  printf '%s\n' "${BOOTSTRAP_ROOT}/config/skill-blacklist.json"
}

skill_blacklist_is_valid() {
  # Validate the security policy before any installer call. A missing,
  # unreadable, or structurally malformed deny list is a failed safety control,
  # so shared-skill synchronization must stop instead of silently allowing all
  # candidates through.
  local file
  file="$(skill_blacklist_file)"
  [[ -f "$file" ]] || return 1
  python3 - "$file" <<'PY'
"""Validate the deny-list schema needed by the shell enforcement boundary."""

import json
import sys
from pathlib import Path

try:
    data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
except (OSError, ValueError):
    raise SystemExit(1)

if not isinstance(data, dict) or not isinstance(data.get("entries"), list):
    raise SystemExit(1)
for entry in data["entries"]:
    if not isinstance(entry, dict) or not isinstance(entry.get("names"), list):
        raise SystemExit(1)
    if not all(isinstance(name, str) and name for name in entry["names"]):
        raise SystemExit(1)
raise SystemExit(0)
PY
}

skill_is_blacklisted() {
  # Succeed when the candidate name equals any deny-list entry under full
  # Unicode case folding; never prefix-, suffix-, or fuzzy-match. Configuration
  # errors conservatively count as blocked here as a race-safe backstop; the
  # public sync boundary separately fails the whole operation during preflight.
  local candidate file
  candidate="${1:-}"
  file="$(skill_blacklist_file)"
  [[ -n "$candidate" ]] || return 1
  [[ -f "$file" ]] || return 0
  python3 - "$candidate" "$file" <<'PY'
"""Case-fold the candidate and every deny-list name, then require an exact hit."""

import json
import sys
from pathlib import Path

candidate = sys.argv[1].casefold()
try:
    data = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
except (OSError, ValueError):
    raise SystemExit(0)
if not isinstance(data, dict) or not isinstance(data.get("entries"), list):
    raise SystemExit(0)
for entry in data["entries"]:
    if not isinstance(entry, dict) or not isinstance(entry.get("names"), list):
        raise SystemExit(0)
    for name in entry["names"]:
        if not isinstance(name, str) or not name:
            raise SystemExit(0)
        if name.casefold() == candidate:
            raise SystemExit(0)
raise SystemExit(1)
PY
}

list_source_skills() {
  # ponytail: parse the CLI table; replace this with JSON when skills exposes it.
  local source="$1"
  local output
  output="$(
    set -o pipefail
    (
      cd "$HOME" || exit 1
      DISABLE_TELEMETRY=1 DO_NOT_TRACK=1 \
        npx --yes skills add "$source" --list < /dev/null
    ) 2>&1 |
      python3 -c '
import re
import sys

ansi = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
skill_name = re.compile(r"^│ {4}(\S.*)$")
for raw in sys.stdin:
    line = ansi.sub("", raw).replace("\r", "")
    match = skill_name.match(line)
    if match:
        print(match.group(1).strip())
'
  )" || return 1
  [[ -n "$output" ]] || return 1
  printf '%s\n' "$output"
}

run_skills_add() {
  local source="$1"
  shift
  (
    cd "$HOME" || exit 1
    DISABLE_TELEMETRY=1 DO_NOT_TRACK=1 \
      npx --yes skills add "$source" "$@" \
        --agent universal \
        --agent codex \
        --agent claude-code \
        --agent antigravity \
        --agent antigravity-cli \
        --agent github-copilot \
        --yes < /dev/null
  )
}

skills_list_path() {
  if [[ -n "${SKILLS_LIST_FILE:-}" ]]; then
    printf '%s\n' "$SKILLS_LIST_FILE"
    return 0
  fi

  ensure_state_dirs
  local target="${BOOTSTRAP_STATE_DIR}/skills-discovered.tsv"
  if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
    printf '%s\n' "$target"
    return 0
  fi
  python3 "${BOOTSTRAP_ROOT}/scripts/discover-skills.py" > "${target}.tmp"
  mv "${target}.tmp" "$target"
  printf '%s\n' "$target"
}

write_skills_report() {
  local installed="$1"
  local skipped="$2"
  local failed="$3"
  local failure_file="$4"
  local report="${BOOTSTRAP_STATE_DIR}/skills-report.json"
  ensure_state_dirs

  {
    printf '{\n'
    printf '  "generatedAt": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "canonicalDirectory": "%s",\n' "$(json_escape "${SKILLS_CANONICAL_DIR:-${HOME}/.agents/skills}")"
    printf '  "installed": %d,\n' "$installed"
    printf '  "skipped": %d,\n' "$skipped"
    printf '  "failed": %d,\n' "$failed"
    printf '  "failures": ['
    local first=1
    local source skill exit_code
    while IFS=$'\t' read -r source skill exit_code; do
      [[ -n "$source" ]] || continue
      if (( first == 0 )); then
        printf ','
      fi
      printf '\n    {"source": "%s", "skill": "%s", "exitCode": %d}' \
        "$(json_escape "$source")" "$(json_escape "$skill")" "$exit_code"
      first=0
    done < "$failure_file"
    if (( first == 0 )); then
      printf '\n  '
    fi
    printf ']\n}\n'
  } > "${report}.tmp"
  mv "${report}.tmp" "$report"
}

skill_is_installed() {
  local source="$1"
  local skill="$2"
  local canonical="${SKILLS_CANONICAL_DIR:-${HOME}/.agents/skills}"
  local lock_file="${SKILLS_LOCK_FILE:-${HOME}/skills-lock.json}"

  [[ -f "$lock_file" ]] || return 1
  python3 - "$lock_file" "$canonical" "$source" "$skill" <<'PY'
import json
import sys
from pathlib import Path

lock_path, canonical_path, source, requested = sys.argv[1:]
# A lock entry proves that one named skill was installed, but it does not prove
# that a wildcard source was fully synchronized. Wildcards therefore reconcile
# until the lock format gains an explicit full-source completion marker.
if requested == "*":
    raise SystemExit(1)

try:
    skills = json.loads(Path(lock_path).read_text()).get("skills", {})
except (OSError, json.JSONDecodeError):
    raise SystemExit(1)

matching = [
    name
    for name, metadata in skills.items()
    if isinstance(metadata, dict)
    and metadata.get("source") == source
    and name == requested
]
if matching and all((Path(canonical_path) / name / "SKILL.md").is_file() for name in matching):
    raise SystemExit(0)
raise SystemExit(1)
PY
}

install_one_skill() {
  local source="$1"
  local skill="$2"
  if [[ "$skill" != "*" ]]; then
    run_skills_add "$source" --skill "$skill"
    return
  fi

  local available
  local name
  local install_args=()
  available="$(list_source_skills "$source")" || return 1
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    if skill_conflicts_with_client_command "$name"; then
      log "Skipping ${source}/${name}: conflicts with a client command"
    elif skill_is_blacklisted "$name"; then
      log "Skipping ${source}/${name}: blacklisted"
    else
      install_args+=(--skill "$name")
    fi
  done <<< "$available"

  if ((${#install_args[@]} == 0)); then
    log "Skipping ${source}: all skills conflict with client commands"
    # Return a distinct result so the report does not count a deliberate skip as an install.
    return 2
  fi
  local status
  if run_skills_add "$source" "${install_args[@]}"; then
    return 0
  else
    status=$?
  fi
  # A child CLI's status 2 is an installation failure when non-conflicting
  # skills were selected; status 2 is reserved for the all-conflict skip above.
  (( status == 2 )) && return 1
  return "$status"
}

install_shared_skills() {
  if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
    log "DRY-RUN discover and install all Official and Topic skills into ${SKILLS_CANONICAL_DIR:-${HOME}/.agents/skills}"
    record_result skills changed "planned shared skills refresh"
    return 0
  fi
  if ! command_exists python3; then
    die "python3 is required for skills discovery"
    record_result skills failed "python3 missing"
    return 1
  fi
  if ! command_exists npx; then
    die "npx is required for skills installation"
    record_result skills failed "npx missing"
    return 1
  fi
  if ! skill_blacklist_is_valid; then
    die "skill deny list is missing, unreadable, or malformed"
    record_result skills failed "skill deny list invalid"
    return 1
  fi

  local canonical="${SKILLS_CANONICAL_DIR:-${HOME}/.agents/skills}"
  local list_file
  list_file="$(skills_list_path)" || {
    record_result skills failed "catalog discovery failed"
    return 1
  }

  mkdir -p "$canonical"
  ensure_state_dirs
  local failures
  failures="$(mktemp "${TMPDIR:-/tmp}/skill-failures.XXXXXX")"
  local wildcard_reconciled
  wildcard_reconciled="$(mktemp "${TMPDIR:-/tmp}/skill-wildcards.XXXXXX")"
  local installed=0
  local skipped=0
  local failed=0
  local source skill status

  while IFS=$'\t' read -r source skill; do
    [[ -n "$source" && -n "$skill" ]] || continue
    if skill_conflicts_with_client_command "$skill"; then
      log "Skipping ${source}/${skill}: conflicts with a client command"
      skipped=$((skipped + 1))
    elif skill_is_blacklisted "$skill"; then
      log "Skipping ${source}/${skill}: blacklisted"
      skipped=$((skipped + 1))
    elif skill_is_installed "$source" "$skill"; then
      skipped=$((skipped + 1))
    elif install_one_skill "$source" "$skill"; then
      installed=$((installed + 1))
    else
      status=$?
      if (( status == 2 )); then
        skipped=$((skipped + 1))
      elif [[ "$skill" != "*" ]] &&
        { grep -Fxq "$source" "$wildcard_reconciled" ||
          install_one_skill "$source" "*"; }; then
        # skills.sh topic entries can briefly retain an old name after its
        # repository renames or consolidates a skill. Installing every current
        # skill from that same source preserves the requested catalog coverage.
        grep -Fxq "$source" "$wildcard_reconciled" ||
          printf '%s\n' "$source" >> "$wildcard_reconciled"
        installed=$((installed + 1))
      else
        failed=$((failed + 1))
        printf '%s\t%s\t%d\n' "$source" "$skill" "$status" >> "$failures"
      fi
    fi
  done < "$list_file"

  write_skills_report "$installed" "$skipped" "$failed" "$failures"
  rm -f "$failures" "$wildcard_reconciled"

  if (( failed > 0 )); then
    record_result skills failed "${failed} skill installation(s) failed"
    return 1
  fi
  if (( installed == 0 )); then
    record_result skills ok "${skipped} already-installed skill entries skipped"
  else
    record_result skills changed "${installed} skills installed; ${skipped} already installed"
  fi
}
