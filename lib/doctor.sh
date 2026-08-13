#!/usr/bin/env bash

doctor_results_file=""
doctor_failure_count=0

doctor_add() {
  local id="$1"
  local name="$2"
  local status_value="$3"
  local detail="$4"
  printf '%s\t%s\t%s\t%s\n' "$id" "$name" "$status_value" "$detail" >> "$doctor_results_file"
  if [[ "${BOOTSTRAP_OUTPUT_FORMAT:-human}" != "json" ]]; then
    printf '%-7s %-5s %s — %s\n' "$id" "$status_value" "$name" "$detail"
  fi
  if [[ "$status_value" == "fail" ]]; then
    doctor_failure_count=$((doctor_failure_count + 1))
  fi
}

doctor_has_commands() {
  local item
  for item in "$@"; do
    command_exists "$item" || return 1
  done
}

doctor_file_contains() {
  local file="$1"
  local pattern="$2"
  [[ -f "$file" ]] && grep -Fq "$pattern" "$file"
}

doctor_colima_runtime() {
  command_exists colima || return 1
  colima status --json 2>/dev/null |
    python3 -c '
import json
import sys

try:
    value = json.load(sys.stdin)
except (json.JSONDecodeError, OSError, TypeError):
    raise SystemExit(1)

raise SystemExit(
    0 if isinstance(value, dict) and value.get("runtime") == "containerd" else 1
)
'
}

doctor_json_has_all_mcp() {
  local file="$1"
  local section="${2:-mcpServers}"
  [[ -f "$file" ]] || return 1
  python3 - "$file" "$section" <<'PY' >/dev/null 2>&1
import json, sys
required = {"sequential-thinking", "time", "deepwiki", "context7", "memory", "codegraph", "figma"}
value = json.load(open(sys.argv[1]))
for key in filter(None, sys.argv[2].split(".")):
    value = value[key]
raise SystemExit(0 if isinstance(value, dict) and required <= set(value) else 1)
PY
}

doctor_mcp_configs() {
  local catalog="${BOOTSTRAP_ROOT}/config/mcp-servers.json"
  if ! python3 - "$catalog" <<'PY' >/dev/null 2>&1
import json, sys
required = {"sequential-thinking", "time", "deepwiki", "context7", "memory", "codegraph", "figma"}
servers = json.load(open(sys.argv[1]))["mcpServers"]
raise SystemExit(0 if required <= set(servers) else 1)
PY
  then
    return 1
  fi

  local required_name output
  output="$(codex mcp list 2>/dev/null)" || return 1
  for required_name in sequential-thinking time deepwiki context7 memory codegraph figma; do
    printf '%s\n' "$output" | grep -Fq "$required_name" || return 1
  done
  output="$(claude mcp list 2>/dev/null)" || return 1
  for required_name in sequential-thinking time deepwiki context7 memory codegraph figma; do
    printf '%s\n' "$output" | grep -Fq "$required_name" || return 1
  done
  doctor_json_has_all_mcp "${HOME}/.copilot/mcp-config.json" || return 1
  doctor_json_has_all_mcp "${HOME}/.gemini/config/mcp_config.json" || return 1
  doctor_json_has_all_mcp "${HOME}/Library/Application Support/Code/User/mcp.json" servers || return 1
  doctor_file_contains "${HOME}/.agents/AGENTS.md" "codegraph init" &&
    doctor_file_contains "${HOME}/.agents/AGENTS.md" "DietrichGebert/ponytail"
}

doctor_skills() {
  [[ -d "${HOME}/.agents/skills" ]] || return 1
  find "${HOME}/.agents/skills" -mindepth 1 -maxdepth 1 -type d -print -quit 2>/dev/null |
    grep -q .
}

doctor_figma() {
  doctor_file_contains "${BOOTSTRAP_ROOT}/config/mcp-servers.json" "https://mcp.figma.com/mcp" &&
    doctor_file_contains "${HOME}/.copilot/mcp-config.json" "figma" &&
    doctor_file_contains "${HOME}/.gemini/config/mcp_config.json" "figma" &&
    doctor_file_contains "${HOME}/Library/Application Support/Code/User/mcp.json" "figma"
}

doctor_glances_all() {
  local receipt="${HOME}/.local/share/uv/tools/glances/uv-receipt.toml"
  command_exists glances &&
    doctor_file_contains "$receipt" 'name = "glances"' &&
    doctor_file_contains "$receipt" 'extras = ["all"]'
}

doctor_standards() {
  local file="${1:-${BOOTSTRAP_ROOT}/docs/standards.md}"
  local marker
  [[ -f "$file" ]] || return 1
  for marker in "APA 7" "NIST SP 800-218" "SLSA v1.2" "SOC 2" "CSAP"; do
    doctor_file_contains "$file" "$marker" || return 1
  done
}

doctor_git_flow() {
  command_exists git || return 1
  local branches
  branches="$(git -C "$BOOTSTRAP_ROOT" branch --list main develop 2>/dev/null)" || return 1
  printf '%s\n' "$branches" | sed -E 's/^[*+[:space:]]+//' | grep -Fxq main &&
    printf '%s\n' "$branches" | sed -E 's/^[*+[:space:]]+//' | grep -Fxq develop
}

doctor_vpn() {
  command_exists openvpn || return 1
  [[ -d "/Applications/Passepartout.app" || -d "${HOME}/Applications/Passepartout.app" ]]
}

doctor_check_command() {
  local id="$1"
  local name="$2"
  local command_name="$3"
  if command_exists "$command_name"; then
    doctor_add "$id" "$name" pass "${command_name} is available"
  else
    doctor_add "$id" "$name" fail "${command_name} is missing"
  fi
}

doctor_write_report() {
  local target="${BOOTSTRAP_STATE_DIR}/doctor.json"
  {
    printf '{\n  "generatedAt": "%s",\n  "checks": [\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local first=1
    local id name status_value detail
    while IFS=$'\t' read -r id name status_value detail; do
      if (( first == 0 )); then
        printf ',\n'
      fi
      printf '    {"id": "%s", "name": "%s", "status": "%s", "detail": "%s"}' \
        "$(json_escape "$id")" "$(json_escape "$name")" \
        "$(json_escape "$status_value")" "$(json_escape "$detail")"
      first=0
    done < "$doctor_results_file"
    printf '\n  ],\n  "failures": %d\n}\n' "$doctor_failure_count"
  } > "${target}.tmp"
  mv "${target}.tmp" "$target"
}

doctor_emit_report() {
  if [[ "${BOOTSTRAP_OUTPUT_FORMAT:-human}" == "json" ]]; then
    cat "${BOOTSTRAP_STATE_DIR}/doctor.json"
  fi
}

run_doctor() {
  ensure_state_dirs
  doctor_results_file="$(mktemp "${TMPDIR:-/tmp}/doctor-results.XXXXXX")"
  doctor_failure_count=0

  doctor_check_command REQ-01 Homebrew brew
  doctor_check_command REQ-02 Codex codex
  doctor_check_command REQ-03 GitHub-CLI gh
  doctor_check_command REQ-04 Antigravity agy
  doctor_check_command REQ-05 Claude-Code claude
  doctor_check_command REQ-06 VS-Code code
  doctor_check_command REQ-07 Copilot-CLI copilot

  if doctor_has_commands codegraph npx uvx && doctor_mcp_configs; then
    doctor_add REQ-08 MCP-and-extensions pass "catalog and client adapters are configured"
  else
    doctor_add REQ-08 MCP-and-extensions fail "MCP, Ponytail, or CodeGraph evidence is incomplete"
  fi
  if doctor_skills; then
    doctor_add REQ-09 Shared-skills pass "${HOME}/.agents/skills contains skills"
  else
    doctor_add REQ-09 Shared-skills fail "${HOME}/.agents/skills is empty or missing"
  fi
  if doctor_figma; then
    doctor_add REQ-10 Figma pass "official remote Figma MCP is configured"
  else
    doctor_add REQ-10 Figma fail "Figma MCP configuration is incomplete"
  fi
  if doctor_has_commands mise uv node npm pnpm java go rustc cargo dotnet clang cmake ninja conan; then
    doctor_add REQ-11 Language-managers pass "Python, Java, Node, Go, Rust, .NET, C and C++ tooling is available"
  else
    doctor_add REQ-11 Language-managers fail "one or more runtime managers are missing"
  fi
  if doctor_file_contains "${HOME}/.zshrc" "BEGIN macos-ai-bootstrap:ai-native-shell"; then
    doctor_add REQ-12 AI-native-shell pass "managed zsh block is present"
  else
    doctor_add REQ-12 AI-native-shell fail "managed zsh block is missing"
  fi
  if doctor_has_commands btop && doctor_glances_all; then
    doctor_add REQ-13 Monitoring pass "glances[all] uv tool and btop are available"
  else
    doctor_add REQ-13 Monitoring fail "glances[all] receipt or monitoring commands are missing"
  fi
  if doctor_has_commands colima nerdctl &&
    doctor_file_contains "${BOOTSTRAP_ROOT}/config/colima.yaml" "runtime: containerd" &&
    doctor_colima_runtime; then
    doctor_add REQ-14 Containers pass "Colima default profile is running with containerd and nerdctl is available"
  else
    doctor_add REQ-14 Containers fail "Colima containerd environment is incomplete"
  fi
  if doctor_git_flow; then
    doctor_add REQ-15 Git-and-Git-Flow pass "git and Git Flow branches are available"
  else
    doctor_add REQ-15 Git-and-Git-Flow fail "git or Git Flow branches are missing"
  fi
  if doctor_vpn; then
    doctor_add REQ-16 VPN pass "OpenVPN and Passepartout are available"
  else
    doctor_add REQ-16 VPN fail "OpenVPN or Passepartout is missing"
  fi
  if doctor_has_commands kubectl helm k9s colima; then
    doctor_add REQ-17 Kubernetes-lab pass "on-demand Colima k3s tooling is available"
  else
    doctor_add REQ-17 Kubernetes-lab fail "kubectl, Helm, k9s, or Colima is missing"
  fi
  if doctor_file_contains "${BOOTSTRAP_ROOT}/docs/korean-manual.md" "빠른 시작"; then
    doctor_add REQ-18 Korean-manual pass "Korean operator manual is available"
  else
    doctor_add REQ-18 Korean-manual fail "Korean operator manual is missing"
  fi
  if [[ -f "${HOME}/.config/macos-ai-bootstrap/ime.lua" ]] &&
    doctor_file_contains "${HOME}/.config/macos-ai-bootstrap/ime.lua" "3-Set Korean (390)" &&
    [[ -d "/Applications/Hammerspoon.app" || -d "${HOME}/Applications/Hammerspoon.app" ]]; then
    doctor_add REQ-19 Sebeolsik-IME pass "built-in 390 Sebeolsik Hammerspoon toggle is configured"
  else
    doctor_add REQ-19 Sebeolsik-IME fail "Hammerspoon or Sebeolsik toggle configuration is missing"
  fi
  if command_exists caffeinate && [[ -x "${HOME}/.local/bin/ai-awake" ]]; then
    doctor_add REQ-20 Awake-wrapper pass "ai-awake and macOS caffeinate are available"
  else
    doctor_add REQ-20 Awake-wrapper fail "ai-awake or caffeinate is missing"
  fi
  if doctor_standards; then
    doctor_add REQ-21 Security-and-compliance pass "local NIST, SLSA, SOC 2, and CSAP evidence is documented"
  else
    doctor_add REQ-21 Security-and-compliance fail "security and compliance evidence is missing or incomplete"
  fi

  doctor_write_report
  rm -f "$doctor_results_file"
  doctor_emit_report

  if (( doctor_failure_count > 0 )); then
    record_result doctor failed "${doctor_failure_count} requirement(s) failed"
    return 1
  fi
  record_result doctor unchanged "all 21 requirements passed"
}
