#!/usr/bin/env bash

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
try:
    skills = json.loads(Path(lock_path).read_text()).get("skills", {})
except (OSError, json.JSONDecodeError):
    raise SystemExit(1)

matching = [
    name
    for name, metadata in skills.items()
    if isinstance(metadata, dict)
    and metadata.get("source") == source
    and (requested == "*" or name == requested)
]
if matching and all((Path(canonical_path) / name / "SKILL.md").is_file() for name in matching):
    raise SystemExit(0)
raise SystemExit(1)
PY
}

install_one_skill() {
  local source="$1"
  local skill="$2"
  (
    cd "$HOME"
    DISABLE_TELEMETRY=1 DO_NOT_TRACK=1 \
      npx --yes skills add "$source" \
        --skill "$skill" \
        --agent universal \
        --agent codex \
        --agent claude-code \
        --agent antigravity \
        --agent antigravity-cli \
        --agent github-copilot \
        --yes < /dev/null
  )
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
    if skill_is_installed "$source" "$skill"; then
      skipped=$((skipped + 1))
    elif install_one_skill "$source" "$skill"; then
      installed=$((installed + 1))
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
      status=$?
      failed=$((failed + 1))
      printf '%s\t%s\t%d\n' "$source" "$skill" "$status" >> "$failures"
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
