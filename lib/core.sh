#!/usr/bin/env bash

if [[ -n "${BOOTSTRAP_CORE_LOADED:-}" ]]; then
  # shellcheck disable=SC2317
  return 0 2>/dev/null || exit 0
fi
BOOTSTRAP_CORE_LOADED=1

BOOTSTRAP_DRY_RUN="${BOOTSTRAP_DRY_RUN:-0}"
BOOTSTRAP_ONLY="${BOOTSTRAP_ONLY:-}"
BOOTSTRAP_SKIP="${BOOTSTRAP_SKIP:-}"
BOOTSTRAP_YES="${BOOTSTRAP_YES:-0}"
BOOTSTRAP_VERBOSE="${BOOTSTRAP_VERBOSE:-0}"
BOOTSTRAP_STATE_DIR="${BOOTSTRAP_STATE_DIR:-${HOME}/.local/state/macos-ai-bootstrap}"
BOOTSTRAP_BACKUP_DIR="${BOOTSTRAP_BACKUP_DIR:-${BOOTSTRAP_STATE_DIR}/backups}"

log() {
  printf '[bootstrap] %s\n' "$(redact "$*")" >&2
}

debug() {
  if [[ "$BOOTSTRAP_VERBOSE" == "1" ]]; then
    printf '[bootstrap:debug] %s\n' "$(redact "$*")" >&2
  fi
}

die() {
  log "ERROR: $*"
  return 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

csv_contains() {
  local csv="${1:-}"
  local value="$2"
  [[ ",${csv}," == *",${value},"* ]]
}

phase_selected() {
  local phase="$1"
  if [[ -n "$BOOTSTRAP_ONLY" ]] && ! csv_contains "$BOOTSTRAP_ONLY" "$phase"; then
    return 1
  fi
  if [[ -n "$BOOTSTRAP_SKIP" ]] && csv_contains "$BOOTSTRAP_SKIP" "$phase"; then
    return 1
  fi
  return 0
}

quote_command() {
  local output=""
  local item
  for item in "$@"; do
    printf -v item '%q' "$item"
    output="${output}${output:+ }${item}"
  done
  printf '%s' "$output"
}

run() {
  if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
    log "DRY-RUN $(quote_command "$@")"
    return 0
  fi
  debug "RUN $(quote_command "$@")"
  "$@"
}

redact() {
  printf '%s\n' "$*" |
    sed -E \
      -e 's/([Tt][Oo][Kk][Ee][Nn]|[A-Za-z_]*[Kk][Ee][Yy]|[Ss][Ee][Cc][Rr][Ee][Tt])=([^[:space:]]+)/\1=[REDACTED]/g' \
      -e 's/([Aa]uthorization:)[[:space:]]*Bearer[[:space:]]+[^[:space:]]+/\1 [REDACTED]/g'
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

ensure_state_dirs() {
  if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
    return 0
  fi
  mkdir -p "$BOOTSTRAP_STATE_DIR" "$BOOTSTRAP_BACKUP_DIR"
}

record_result() {
  local phase="$1"
  local status="$2"
  local detail="${3:-}"
  local report="${BOOTSTRAP_STATE_DIR}/results.jsonl"
  ensure_state_dirs
  if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
    log "${phase}: ${status} ${detail}"
    return 0
  fi
  printf '{"phase":"%s","status":"%s","detail":"%s","timestamp":"%s"}\n' \
    "$(json_escape "$phase")" \
    "$(json_escape "$status")" \
    "$(json_escape "$(redact "$detail")")" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$report"
}

backup_file() {
  local target="$1"
  if [[ ! -f "$target" || "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
    return 0
  fi
  ensure_state_dirs
  local safe_name
  safe_name="$(printf '%s' "$target" | sed 's#[^A-Za-z0-9._-]#_#g')"
  cp -p "$target" "${BOOTSTRAP_BACKUP_DIR}/${safe_name}.$(date +%Y%m%d%H%M%S).bak"
}

managed_block() {
  local target="$1"
  local block_name="$2"
  local source_file="$3"
  local begin="# BEGIN macos-ai-bootstrap:${block_name}"
  local end="# END macos-ai-bootstrap:${block_name}"
  local parent
  parent="$(dirname "$target")"

  if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
    log "DRY-RUN update managed block ${block_name} in ${target}"
    return 0
  fi

  mkdir -p "$parent"
  [[ -e "$target" ]] || : > "$target"
  backup_file "$target"

  local temporary
  temporary="$(mktemp "${TMPDIR:-/tmp}/managed-block.XXXXXX")"
  awk -v begin="$begin" -v end="$end" '
    $0 == begin { skipping=1; next }
    $0 == end { skipping=0; next }
    !skipping { print }
  ' "$target" > "$temporary"

  while [[ -s "$temporary" ]] && [[ "$(tail -c 1 "$temporary" 2>/dev/null || true)" == "" ]] && [[ "$(tail -n 1 "$temporary")" == "" ]]; do
    sed -i.bak '$d' "$temporary"
    rm -f "${temporary}.bak"
  done

  {
    cat "$temporary"
    if [[ -s "$temporary" ]]; then
      printf '\n'
    fi
    printf '%s\n' "$begin"
    cat "$source_file"
    [[ "$(tail -c 1 "$source_file" 2>/dev/null || true)" == "" ]] || printf '\n'
    printf '%s\n' "$end"
  } > "${temporary}.new"
  mv "${temporary}.new" "$target"
  rm -f "$temporary"
}
