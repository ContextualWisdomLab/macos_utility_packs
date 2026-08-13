#!/usr/bin/env bash

set -u

# shellcheck source=tests/test_helper.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test_helper.sh"
setup_test_env
trap teardown_test_env EXIT

cat > "${TEST_ROOT}/bin/caffeinate" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$MOCK_CAFFEINATE_LOG"
MOCK
chmod +x "${TEST_ROOT}/bin/caffeinate"
export MOCK_CAFFEINATE_LOG="${TEST_ROOT}/caffeinate.log"

bash "${BOOTSTRAP_ROOT}/bin/ai-awake" codex --help
assert_file_contains "$MOCK_CAFFEINATE_LOG" '-dimsu codex --help' "ai-awake keeps the Mac awake for Codex lifetime"

if bash "${BOOTSTRAP_ROOT}/bin/ai-awake" >/dev/null 2>&1; then
  fail "ai-awake rejects a missing command"
else
  pass "ai-awake rejects a missing command"
fi
TEST_COUNT=$((TEST_COUNT + 1))

if bash "${BOOTSTRAP_ROOT}/bin/ai-awake" caffeinate >/dev/null 2>&1; then
  fail "ai-awake rejects recursive caffeinate invocation"
else
  pass "ai-awake rejects recursive caffeinate invocation"
fi
TEST_COUNT=$((TEST_COUNT + 1))

source "${BOOTSTRAP_ROOT}/lib/core.sh"
source "${BOOTSTRAP_ROOT}/lib/shell.sh"
BOOTSTRAP_DRY_RUN=0
install_ai_awake >/dev/null
assert_file_contains "${HOME}/.local/bin/ai-awake" 'caffeinate' "ai-awake is installed in user PATH"

manual="${BOOTSTRAP_ROOT}/docs/korean-manual.md"
assert_file_contains "$manual" 'ai-awake codex' "Korean manual explains awake wrapper"
assert_file_contains "$manual" '절전' "Korean manual explains sleep prevention"
assert_file_contains "${BOOTSTRAP_ROOT}/config/zshrc.block" "codex-awake='ai-awake codex'" "shell exposes a Codex awake shortcut"
assert_file_contains "${BOOTSTRAP_ROOT}/config/zshrc.block" "claude-awake='ai-awake claude'" "shell exposes a Claude awake shortcut"

finish_tests
