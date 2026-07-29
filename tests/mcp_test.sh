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

assert_file_contains "$instructions" 'without waiting for a separate user request' "CodeGraph indexing is autonomous"
assert_file_contains "$instructions" 'codegraph init -i' "CodeGraph indexing command is explicit"
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
  "${HOME}/.gemini/GEMINI.md" \
  "${HOME}/Library/Application Support/Code/User/prompts/macos-ai-bootstrap.instructions.md"; do
  assert_file_contains "$client_instructions" 'codegraph init -i' "CodeGraph guidance reaches ${client_instructions}"
done

assert_file_contains "${BOOTSTRAP_ROOT}/lib/mcp.sh" 'npm install --global @colbymchenry/codegraph' "CodeGraph installs through managed Node npm"
assert_file_contains "${BOOTSTRAP_ROOT}/lib/mcp.sh" 'codegraph install' "CodeGraph native client integration is installed"

finish_tests
