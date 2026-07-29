#!/usr/bin/env bash

doctor_results_file=""
doctor_failure_count=0

doctor_add() {
  local id="$1"
  local name="$2"
  local status_value="$3"
  local detail="$4"
  printf '%s\t%s\t%s\t%s\n' "$id" "$name" "$status_value" "$detail" >> "$doctor_results_file"
  printf '%-7s %-5s %s — %s\n' "$id" "$status_value" "$name" "$detail"
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
  python3 - "$catalog" <<'PY' >/dev/null 2>&1
import json, sys
required = {"sequential-thinking", "time", "deepwiki", "context7", "memory", "codegraph", "figma"}
servers = json.load(open(sys.argv[1]))["mcpServers"]
raise SystemExit(0 if required <= set(servers) else 1)
PY
  [[ $? -eq 0 ]] || return 1

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
  doctor_json_has_all_mcp "${HOME}/Library/Application Support/Code/User/mcp.json" || return 1
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

run_doctor() {
  ensure_state_dirs
  doctor_results_file="$(mktemp "${TMPDIR:-/tmp}/doctor-results.XXXXXX")"
  doctor_failure_count=0

  command_exists brew &&
    doctor_add REQ-01 Homebrew pass "brew is available" ||
    doctor_add REQ-01 Homebrew fail "brew is missing"
  command_exists codex &&
    doctor_add REQ-02 Codex pass "codex is available" ||
    doctor_add REQ-02 Codex fail "codex is missing"
  command_exists gh &&
    doctor_add REQ-03 GitHub-CLI pass "gh is available" ||
    doctor_add REQ-03 GitHub-CLI fail "gh is missing"
  command_exists agy &&
    doctor_add REQ-04 Antigravity pass "agy is available" ||
    doctor_add REQ-04 Antigravity fail "agy is missing"
  command_exists claude &&
    doctor_add REQ-05 Claude-Code pass "claude is available" ||
    doctor_add REQ-05 Claude-Code fail "claude is missing"
  command_exists code &&
    doctor_add REQ-06 VS-Code pass "code is available" ||
    doctor_add REQ-06 VS-Code fail "code is missing"
  command_exists copilot &&
    doctor_add REQ-07 Copilot-CLI pass "copilot is available" ||
    doctor_add REQ-07 Copilot-CLI fail "copilot is missing"

  if doctor_has_commands codegraph npx uvx && doctor_mcp_configs; then
    doctor_add REQ-08 MCP-and-extensions pass "catalog and client adapters are configured"
  else
    doctor_add REQ-08 MCP-and-extensions fail "MCP, Ponytail, or CodeGraph evidence is incomplete"
  fi
  doctor_skills &&
    doctor_add REQ-09 Shared-skills pass "~/.agents/skills contains skills" ||
    doctor_add REQ-09 Shared-skills fail "~/.agents/skills is empty or missing"
  doctor_figma &&
    doctor_add REQ-10 Figma pass "official remote Figma MCP is configured" ||
    doctor_add REQ-10 Figma fail "Figma MCP configuration is incomplete"
  doctor_has_commands mise uv node npm pnpm java go rustc cargo dotnet clang cmake ninja conan &&
    doctor_add REQ-11 Language-managers pass "Python, Java, Node, Go, Rust, .NET, C and C++ tooling is available" ||
    doctor_add REQ-11 Language-managers fail "one or more runtime managers are missing"
  doctor_file_contains "${HOME}/.zshrc" "BEGIN macos-ai-bootstrap:ai-native-shell" &&
    doctor_add REQ-12 AI-native-shell pass "managed zsh block is present" ||
    doctor_add REQ-12 AI-native-shell fail "managed zsh block is missing"
  doctor_has_commands glances btop &&
    doctor_add REQ-13 Monitoring pass "glances and btop are available" ||
    doctor_add REQ-13 Monitoring fail "monitoring commands are missing"
  if doctor_has_commands colima nerdctl &&
    doctor_file_contains "${BOOTSTRAP_ROOT}/config/colima.yaml" "runtime: containerd"; then
    doctor_add REQ-14 Containers pass "Colima containerd and nerdctl are available"
  else
    doctor_add REQ-14 Containers fail "Colima containerd environment is incomplete"
  fi
  doctor_git_flow &&
    doctor_add REQ-15 Git-and-Git-Flow pass "git and Git Flow branches are available" ||
    doctor_add REQ-15 Git-and-Git-Flow fail "git or Git Flow branches are missing"
  doctor_vpn &&
    doctor_add REQ-16 VPN pass "OpenVPN and Passepartout are available" ||
    doctor_add REQ-16 VPN fail "OpenVPN or Passepartout is missing"
  doctor_has_commands kubectl helm k9s colima &&
    doctor_add REQ-17 Kubernetes-lab pass "on-demand Colima k3s tooling is available" ||
    doctor_add REQ-17 Kubernetes-lab fail "kubectl, Helm, k9s, or Colima is missing"
  doctor_file_contains "${BOOTSTRAP_ROOT}/docs/한국어-매뉴얼.md" "빠른 시작" &&
    doctor_add REQ-18 Korean-manual pass "Korean operator manual is available" ||
    doctor_add REQ-18 Korean-manual fail "Korean operator manual is missing"
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

  doctor_write_report
  rm -f "$doctor_results_file"

  if (( doctor_failure_count > 0 )); then
    record_result doctor failed "${doctor_failure_count} requirement(s) failed"
    return 1
  fi
  record_result doctor unchanged "all 20 requirements passed"
}
