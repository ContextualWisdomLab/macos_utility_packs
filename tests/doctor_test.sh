#!/usr/bin/env bash

set -u

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test_helper.sh"
setup_test_env
trap teardown_test_env EXIT

mock_commands=(brew codex gh agy claude code copilot codegraph npx uvx mise uv node npm pnpm java go rustc cargo dotnet clang cmake ninja conan glances btop colima nerdctl kubectl helm k9s git openvpn caffeinate)
for command_name in "${mock_commands[@]}"; do
  cat > "${TEST_ROOT}/bin/${command_name}" <<MOCK
#!/usr/bin/env bash
printf '%s %s\n' '${command_name}' "\$*" >> '${TEST_ROOT}/commands.log'
if [[ "\$1" == "--version" || "\$1" == "version" ]]; then
  printf '%s test\n' '${command_name}'
fi
exit 0
MOCK
  chmod +x "${TEST_ROOT}/bin/${command_name}"
done

for agent_command in codex claude; do
  cat > "${TEST_ROOT}/bin/${agent_command}" <<MOCK
#!/usr/bin/env bash
printf '%s %s\n' '${agent_command}' "\$*" >> '${TEST_ROOT}/commands.log'
if [[ "\$*" == "mcp list" ]]; then
  printf '%s\n' sequential-thinking time deepwiki context7 memory codegraph figma
fi
exit 0
MOCK
  chmod +x "${TEST_ROOT}/bin/${agent_command}"
done

mkdir -p \
  "${HOME}/.agents/skills/find-skills" \
  "${HOME}/.copilot" \
  "${HOME}/.gemini/config" \
  "${HOME}/Library/Application Support/Code/User" \
  "${HOME}/Applications/Passepartout.app" \
  "${HOME}/Applications/Hammerspoon.app" \
  "${HOME}/.config/macos-ai-bootstrap"
mkdir -p "${HOME}/.local/share/uv/tools/glances"
printf '%s\n' '[tool]' 'requirements = [{ name = "glances", extras = ["all"] }]' \
  > "${HOME}/.local/share/uv/tools/glances/uv-receipt.toml"
printf '%s\n' '# BEGIN macos-ai-bootstrap:ai-native-shell' > "${HOME}/.zshrc"
printf '%s\n' '# BEGIN macos-ai-bootstrap:shared-agent-instructions' 'codegraph init' 'DietrichGebert/ponytail' > "${HOME}/.agents/AGENTS.md"
cp "${BOOTSTRAP_ROOT}/config/mcp-servers.json" "${HOME}/.copilot/mcp-config.json"
cp "${BOOTSTRAP_ROOT}/config/mcp-servers.json" "${HOME}/.gemini/config/mcp_config.json"
python3 "${BOOTSTRAP_ROOT}/scripts/merge-mcp.py" \
  --target "${HOME}/Library/Application Support/Code/User/mcp.json" \
  --catalog "${BOOTSTRAP_ROOT}/config/mcp-servers.json" \
  --section servers --format vscode
cp "${BOOTSTRAP_ROOT}/config/ime.lua" "${HOME}/.config/macos-ai-bootstrap/ime.lua"
mkdir -p "${HOME}/.local/bin"
cp "${BOOTSTRAP_ROOT}/bin/ai-awake" "${HOME}/.local/bin/ai-awake"

source "${BOOTSTRAP_ROOT}/lib/core.sh"
source "${BOOTSTRAP_ROOT}/lib/doctor.sh"

cat > "${TEST_ROOT}/bin/git" <<MOCK
#!/usr/bin/env bash
if [[ "\$*" == *"branch --list main develop"* ]]; then
  printf '  main\n  develop\n'
fi
printf '%s %s\n' 'git' "\$*" >> '${TEST_ROOT}/commands.log'
exit 0
MOCK
chmod +x "${TEST_ROOT}/bin/git"

if run_doctor >/dev/null; then
  pass "complete fixture passes doctor"
else
  cat "${BOOTSTRAP_STATE_DIR}/doctor.json" >&2
  fail "complete fixture passes doctor"
fi
TEST_COUNT=$((TEST_COUNT + 1))

report="${BOOTSTRAP_STATE_DIR}/doctor.json"
for number in $(seq -w 1 20); do
  assert_file_contains "$report" "\"REQ-${number}\"" "doctor reports REQ-${number}"
done
assert_file_contains "$report" '"status": "pass"' "doctor report contains passing checks"

cp "${HOME}/Library/Application Support/Code/User/mcp.json" "${TEST_ROOT}/vscode-mcp.json"
printf '{"mcpServers":{"context7":{}}}\n' > "${HOME}/Library/Application Support/Code/User/mcp.json"
if doctor_mcp_configs; then
  fail "MCP doctor rejects a client missing required servers"
else
  pass "MCP doctor rejects a client missing required servers"
fi
TEST_COUNT=$((TEST_COUNT + 1))
cp "${TEST_ROOT}/vscode-mcp.json" "${HOME}/Library/Application Support/Code/User/mcp.json"

commands_before="$(cat "${TEST_ROOT}/commands.log")"
assert_not_contains "$commands_before" ' install' "doctor does not install packages"
assert_not_contains "$commands_before" ' add ' "doctor does not add configuration"
assert_not_contains "$commands_before" ' init ' "doctor does not initialize CodeGraph"

assert_file_contains "$report" 'glances[all] uv tool' "doctor reports Glances all extras evidence"

mv "${TEST_ROOT}/bin/codex" "${TEST_ROOT}/codex.disabled"
if run_doctor >/dev/null; then
  fail "missing required binary fails doctor"
else
  pass "missing required binary fails doctor"
fi
TEST_COUNT=$((TEST_COUNT + 1))
assert_file_contains "$report" '"REQ-02"' "failed report still identifies Codex requirement"
assert_file_contains "$report" '"status": "fail"' "failed report records failure"

mv "${TEST_ROOT}/bin/java" "${TEST_ROOT}/java.disabled"
if run_doctor >/dev/null; then
  fail "missing Java runtime fails language manager requirement"
else
  pass "missing Java runtime fails language manager requirement"
fi
TEST_COUNT=$((TEST_COUNT + 1))
assert_file_contains "$report" '"REQ-11"' "language failure is mapped to REQ-11"

cat > "${TEST_ROOT}/bin/git" <<MOCK
#!/usr/bin/env bash
if [[ "\$*" == *"branch --list main develop"* ]]; then
  printf '  main\n'
fi
exit 0
MOCK
chmod +x "${TEST_ROOT}/bin/git"
if doctor_git_flow; then
  fail "Git Flow check rejects a missing develop branch"
else
  pass "Git Flow check rejects a missing develop branch"
fi
TEST_COUNT=$((TEST_COUNT + 1))

finish_tests
