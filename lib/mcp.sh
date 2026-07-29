#!/usr/bin/env bash

mcp_catalog_path() {
  printf '%s/config/mcp-servers.json\n' "$BOOTSTRAP_ROOT"
}

expand_home_path() {
  local path="$1"
  case "$path" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s/%s\n' "$HOME" "${path:2}" ;;
    *) printf '%s\n' "$path" ;;
  esac
}

configure_json_target() {
  local path="$1"
  local section="$2"
  local format="$3"
  local expanded
  expanded="$(expand_home_path "$path")"

  if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
    log "DRY-RUN merge MCP catalog into ${expanded}"
    return 0
  fi
  if [[ -f "$expanded" ]]; then
    backup_file "$expanded"
  fi
  python3 "${BOOTSTRAP_ROOT}/scripts/merge-mcp.py" \
    --target "$expanded" \
    --catalog "$(mcp_catalog_path)" \
    --section "$section" \
    --format "$format"
}

catalog_rows() {
  python3 - "$(mcp_catalog_path)" <<'PY'
import json, sys
items = json.load(open(sys.argv[1]))["mcpServers"]
for name, item in sorted(items.items()):
    args = "\x1f".join(item.get("args", []))
    print("\t".join([name, item["type"], item.get("command", ""), args, item.get("url", "")]))
PY
}

configure_codex_mcp() {
  if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
    log "DRY-RUN reconcile Codex MCP catalog"
    return 0
  fi
  if ! command_exists codex; then
    log "Codex is unavailable; cannot configure its MCP catalog"
    return 1
  fi
  local name type command joined_args url
  while IFS=$'\t' read -r name type command joined_args url; do
    run codex mcp remove "$name" >/dev/null 2>&1 || true
    if [[ "$type" == "http" ]]; then
      run codex mcp add "$name" --url "$url"
    else
      local old_ifs="$IFS"
      IFS=$'\x1f'
      local args=( $joined_args )
      IFS="$old_ifs"
      run codex mcp add "$name" -- "$command" "${args[@]}"
    fi
  done < <(catalog_rows)
}

configure_claude_mcp() {
  if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
    log "DRY-RUN reconcile Claude Code MCP catalog"
    return 0
  fi
  if ! command_exists claude; then
    log "Claude Code is unavailable; cannot configure its MCP catalog"
    return 1
  fi
  local name type command joined_args url
  while IFS=$'\t' read -r name type command joined_args url; do
    run claude mcp remove --scope user "$name" >/dev/null 2>&1 || true
    if [[ "$type" == "http" ]]; then
      run claude mcp add --scope user --transport http "$name" "$url"
    else
      local old_ifs="$IFS"
      IFS=$'\x1f'
      local args=( $joined_args )
      IFS="$old_ifs"
      run claude mcp add --scope user --transport stdio "$name" -- "$command" "${args[@]}"
    fi
  done < <(catalog_rows)
}

install_ai_extensions() {
  if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
    log "DRY-RUN install CodeGraph and Ponytail integrations"
    record_result extensions changed "planned CodeGraph and Ponytail installation"
    return 0
  fi
  local failed=0
  if command_exists npm; then
    run npm install --global @colbymchenry/codegraph || failed=1
    hash -r
    if command_exists codegraph; then
      run codegraph install --target=codex,claude,antigravity --location=global --yes || failed=1
    else
      log "CodeGraph executable is unavailable after npm installation"
      failed=1
    fi
  else
    log "npm is unavailable; cannot install CodeGraph"
    failed=1
  fi

  if command_exists npx; then
    (
      cd "$HOME"
      DISABLE_TELEMETRY=1 DO_NOT_TRACK=1 \
        run npx --yes skills add DietrichGebert/ponytail --skill '*' \
          --agent universal --agent codex --agent claude-code \
          --agent antigravity --agent antigravity-cli \
          --agent github-copilot --yes
    ) || failed=1
  else
    log "npx is unavailable; cannot install Ponytail shared skills"
    failed=1
  fi

  if command_exists codex; then
    run codex plugin marketplace add DietrichGebert/ponytail || failed=1
    run codex plugin add ponytail@ponytail || failed=1
  fi
  if command_exists copilot; then
    run copilot plugin marketplace add DietrichGebert/ponytail || failed=1
    run copilot plugin install ponytail@ponytail || failed=1
  fi
  if command_exists claude; then
    run claude plugin marketplace add DietrichGebert/ponytail || failed=1
    run claude plugin install ponytail@ponytail || failed=1
  fi
  if command_exists agy; then
    run agy plugin install https://github.com/DietrichGebert/ponytail || failed=1
  fi

  if (( failed != 0 )); then
    record_result extensions failed "CodeGraph or Ponytail installation failed"
    return 1
  fi
  record_result extensions changed "CodeGraph and Ponytail reconciled"
}

configure_mcp() {
  local targets_file="${MCP_TARGETS_FILE:-${BOOTSTRAP_ROOT}/config/agent-targets.json}"
  local failures=0
  local name adapter path section format

  while IFS=$'\t' read -r name adapter path section format; do
    case "$adapter" in
      codex-cli) configure_codex_mcp || failures=$((failures + 1)) ;;
      claude-cli) configure_claude_mcp || failures=$((failures + 1)) ;;
      json) configure_json_target "$path" "$section" "$format" || failures=$((failures + 1)) ;;
      *) log "unknown MCP adapter for ${name}: ${adapter}"; failures=$((failures + 1)) ;;
    esac
  done < <(
    python3 - "$targets_file" <<'PY'
import json, sys
for name, item in json.load(open(sys.argv[1]))["targets"].items():
    adapter = item.get("adapter", "json")
    print("\t".join([name, adapter, item.get("path", ""), item.get("section", ""), item.get("format", "generic")]))
PY
  )

  if (( failures > 0 )); then
    record_result mcp failed "${failures} client adapter(s) failed"
    return 1
  fi
  record_result mcp changed "MCP catalog reconciled for all clients"
}

configure_agent_instructions() {
  local instruction_file
  local targets=(
    "${HOME}/.agents/AGENTS.md"
    "${HOME}/.codex/AGENTS.md"
    "${HOME}/.claude/CLAUDE.md"
    "${HOME}/.copilot/copilot-instructions.md"
    "${HOME}/.gemini/GEMINI.md"
  )
  for instruction_file in "${targets[@]}"; do
    managed_block "$instruction_file" "shared-agent-instructions" \
      "${BOOTSTRAP_ROOT}/config/AGENTS.shared.md"
  done

  local vscode_target="${HOME}/Library/Application Support/Code/User/prompts/macos-ai-bootstrap.instructions.md"
  if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
    log "DRY-RUN write auto-applied VS Code instructions to ${vscode_target}"
  else
    mkdir -p "$(dirname "$vscode_target")"
    {
      printf '%s\n' '---' 'applyTo: "**"' '---' ''
      cat "${BOOTSTRAP_ROOT}/config/AGENTS.shared.md"
    } > "${vscode_target}.tmp"
    if [[ -f "$vscode_target" ]] && cmp -s "${vscode_target}.tmp" "$vscode_target"; then
      rm -f "${vscode_target}.tmp"
    else
      [[ -f "$vscode_target" ]] && backup_file "$vscode_target"
      mv "${vscode_target}.tmp" "$vscode_target"
    fi
  fi
  record_result instructions changed "shared guidance reconciled for every client"
}
