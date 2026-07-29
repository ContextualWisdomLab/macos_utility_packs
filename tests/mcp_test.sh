#!/usr/bin/env bash

set -u

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test_helper.sh"
setup_test_env
trap teardown_test_env EXIT

catalog="${BOOTSTRAP_ROOT}/config/mcp-servers.json"
targets="${BOOTSTRAP_ROOT}/config/agent-targets.json"
instructions="${BOOTSTRAP_ROOT}/config/AGENTS.shared.md"

for server in sequential-thinking time deepwiki context7 memory codegraph figma; do
  if python3 - "$catalog" "$server" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
raise SystemExit(0 if sys.argv[2] in data["mcpServers"] else 1)
PY
  then
    pass "MCP catalog includes ${server}"
  else
    fail "MCP catalog includes ${server}"
  fi
  TEST_COUNT=$((TEST_COUNT + 1))
done

for target in codex claude antigravity vscode copilot; do
  if python3 - "$targets" "$target" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
raise SystemExit(0 if sys.argv[2] in data["targets"] else 1)
PY
  then
    pass "agent targets include ${target}"
  else
    fail "agent targets include ${target}"
  fi
  TEST_COUNT=$((TEST_COUNT + 1))
done

figma_url="$(python3 - "$catalog" <<'PY'
import json, sys
print(json.load(open(sys.argv[1]))["mcpServers"]["figma"]["url"])
PY
)"
assert_eq "https://mcp.figma.com/mcp" "$figma_url" "Figma uses official remote MCP"

codegraph_command="$(python3 - "$catalog" <<'PY'
import json, sys
item = json.load(open(sys.argv[1]))["mcpServers"]["codegraph"]
print(" ".join([item["command"], *item["args"]]))
PY
)"
assert_eq "codegraph serve --mcp" "$codegraph_command" "CodeGraph uses documented MCP command"

assert_file_contains "$instructions" 'without waiting for a separate' "CodeGraph indexing is autonomous"
assert_file_contains "$instructions" 'codegraph init' "CodeGraph indexing command is explicit"
assert_not_contains "$(cat "$instructions")" 'codegraph init -i' "CodeGraph guidance avoids the removed -i flag"
assert_file_contains "$instructions" 'DietrichGebert/ponytail' "Ponytail is shared as agent guidance"

target_json="${TEST_ROOT}/client.json"
printf '{"unrelated":{"keep":true},"mcpServers":{"user-server":{"command":"user"}}}\n' > "$target_json"
python3 "${BOOTSTRAP_ROOT}/scripts/merge-mcp.py" \
  --target "$target_json" --catalog "$catalog" --section mcpServers
first_hash="$(shasum -a 256 "$target_json" | awk '{print $1}')"
python3 "${BOOTSTRAP_ROOT}/scripts/merge-mcp.py" \
  --target "$target_json" --catalog "$catalog" --section mcpServers
second_hash="$(shasum -a 256 "$target_json" | awk '{print $1}')"

assert_eq "$first_hash" "$second_hash" "MCP merge is byte-idempotent"
assert_file_contains "$target_json" '"keep": true' "MCP merge preserves unrelated keys"
assert_file_contains "$target_json" '"user-server"' "MCP merge preserves unrelated MCP servers"
assert_file_contains "$target_json" '"figma"' "MCP merge adds managed servers"

source "${BOOTSTRAP_ROOT}/lib/core.sh"
source "${BOOTSTRAP_ROOT}/lib/mcp.sh"

cat > "${TEST_ROOT}/bin/claude" <<'MOCK'
#!/usr/bin/env bash
printf '<%s>\n' "$@" >> "$MOCK_CLAUDE_LOG"
MOCK
chmod +x "${TEST_ROOT}/bin/claude"
export MOCK_CLAUDE_LOG="${TEST_ROOT}/claude.log"
catalog_rows() {
  printf 'empty-list\x1estdio\x1ecommand\x1e\x1e0\x1e\n'
  printf 'empty-arg\x1estdio\x1ecommand\x1e\x1e1\x1e\n'
}
configure_claude_mcp
assert_eq "1" "$(grep -Fxc '<>' "$MOCK_CLAUDE_LOG")" "Claude MCP distinguishes an empty argument from no arguments"
source "${BOOTSTRAP_ROOT}/lib/mcp.sh"

context7_row="$(catalog_rows | grep '^context7')"
IFS=$'\x1e' read -r row_name row_type row_command row_args row_arg_count row_url <<< "$context7_row"
assert_eq "context7" "$row_name" "MCP catalog row preserves HTTP server name"
assert_eq "http" "$row_type" "MCP catalog row preserves HTTP transport"
assert_eq "" "$row_command" "MCP catalog row preserves an empty HTTP command field"
assert_eq "0" "$row_arg_count" "MCP catalog row preserves an empty argument list"
assert_eq "https://mcp.context7.com/mcp" "$row_url" "MCP catalog row preserves HTTP URL after empty fields"

codex_toml="${TEST_ROOT}/config.toml"
printf '%s\n' '[projects."/tmp/example"]' 'trust_level = "trusted"' \
  '[mcp_servers.context7]' 'url = ""' > "$codex_toml"
python3 "${BOOTSTRAP_ROOT}/scripts/merge-codex-mcp.py" \
  --target "$codex_toml" --catalog "$catalog"
codex_first_hash="$(shasum -a 256 "$codex_toml" | awk '{print $1}')"
python3 "${BOOTSTRAP_ROOT}/scripts/merge-codex-mcp.py" \
  --target "$codex_toml" --catalog "$catalog"
codex_second_hash="$(shasum -a 256 "$codex_toml" | awk '{print $1}')"
assert_eq "$codex_first_hash" "$codex_second_hash" "Codex TOML MCP merge is byte-idempotent"
assert_file_contains "$codex_toml" 'trust_level = "trusted"' "Codex TOML MCP merge preserves unrelated settings"
assert_file_contains "$codex_toml" 'url = "https://mcp.context7.com/mcp"' "Codex TOML MCP merge writes the remote URL"
assert_eq "1" "$(grep -Fxc '[mcp_servers.context7]' "$codex_toml")" "Codex TOML MCP merge replaces stale managed sections"
BOOTSTRAP_DRY_RUN=0
export MCP_TARGETS_FILE="${BOOTSTRAP_ROOT}/tests/fixtures/mcp-targets.json"
configure_mcp >/dev/null
assert_file_contains "${HOME}/.copilot/mcp-config.json" '"context7"' "Copilot MCP configuration is written"
assert_file_contains "${HOME}/.gemini/config/mcp_config.json" '"figma"' "Antigravity MCP configuration is written"
assert_file_contains "${HOME}/.gemini/config/mcp_config.json" '"serverUrl": "https://mcp.figma.com/mcp"' "Antigravity remote MCP uses serverUrl"
assert_not_contains "$(cat "${HOME}/.gemini/config/mcp_config.json")" '"url":' "Antigravity remote MCP excludes unsupported url field"

configure_agent_instructions >/dev/null
configure_agent_instructions >/dev/null
assert_eq "1" "$(grep -c 'BEGIN macos-ai-bootstrap:shared-agent-instructions' "${HOME}/.agents/AGENTS.md")" "shared instructions are idempotent"
for client_instructions in \
  "${HOME}/.codex/AGENTS.md" \
  "${HOME}/.claude/CLAUDE.md" \
  "${HOME}/.copilot/copilot-instructions.md" \
  "${HOME}/.gemini/GEMINI.md"; do
  assert_file_contains "$client_instructions" 'codegraph init' "CodeGraph guidance reaches ${client_instructions}"
done
vscode_instructions="${HOME}/Library/Application Support/Code/User/prompts/macos-ai-bootstrap.instructions.md"
assert_file_contains "$vscode_instructions" 'applyTo: "**"' "VS Code instructions apply automatically to every workspace"
assert_file_contains "$vscode_instructions" 'codegraph init' "CodeGraph guidance reaches VS Code"

assert_file_contains "${BOOTSTRAP_ROOT}/lib/mcp.sh" 'npm install --global @colbymchenry/codegraph' "CodeGraph installs through managed Node npm"
assert_file_contains "${BOOTSTRAP_ROOT}/lib/mcp.sh" 'codegraph install' "CodeGraph native client integration is installed"
assert_file_contains "${BOOTSTRAP_ROOT}/lib/mcp.sh" 'merge-codex-mcp.py' "Codex MCP configuration does not trigger OAuth during installation"
assert_file_contains "${BOOTSTRAP_ROOT}/lib/mcp.sh" 'continuing with plugin reconciliation' "existing plugin marketplaces do not break idempotent reruns"
assert_file_contains "${BOOTSTRAP_ROOT}/lib/mcp.sh" 'agy plugin install https://github.com/DietrichGebert/ponytail' "Ponytail uses the official Antigravity plugin installer"

finish_tests
