#!/usr/bin/env bash

set -u

# shellcheck source=tests/test_helper.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test_helper.sh"
setup_test_env
trap teardown_test_env EXIT

mock_commands=(uname sw_vers xcode-select brew mise corepack uv colima kubectl npx pnpm codex claude copilot)
for command_name in "${mock_commands[@]}"; do
  cat > "${TEST_ROOT}/bin/${command_name}" <<MOCK
#!/usr/bin/env bash
case '${command_name}' in
  uname)
    if [[ "\$1" == "-m" ]]; then printf 'arm64\n'; else printf 'Darwin\n'; fi
    ;;
  sw_vers) printf '14.5\n' ;;
  xcode-select) printf '/Library/Developer/CommandLineTools\n' ;;
  brew)
    if [[ "\$1" == "--version" ]]; then printf 'Homebrew test\n'; fi
    ;;
esac
printf '%s %s\n' '${command_name}' "\$*" >> '${TEST_ROOT}/integration-commands.log'
exit 0
MOCK
  chmod +x "${TEST_ROOT}/bin/${command_name}"
done

before="$(find "$HOME" -type f -print | sort)"
output="$(
  HOME="$HOME" \
  PATH="$PATH" \
  BOOTSTRAP_STATE_DIR="$BOOTSTRAP_STATE_DIR" \
  BOOTSTRAP_BACKUP_DIR="$BOOTSTRAP_BACKUP_DIR" \
  bash "${BOOTSTRAP_ROOT}/bootstrap" --dry-run 2>&1
)"
after="$(find "$HOME" -type f -print | sort)"

assert_eq "$before" "$after" "full dry-run does not mutate HOME"
for phase in preflight homebrew packages languages monitoring shell awake ime containers skills extensions mcp instructions; do
  assert_contains "$output" "phase: ${phase}" "full dry-run visits ${phase}"
done
assert_contains "$output" 'brew bundle' "package installation is planned through Homebrew"
assert_contains "$output" 'Glances with all optional integrations' "Glances all extras installation is planned"
assert_contains "$output" 'Official and Topic skills' "dynamic skills refresh is planned"
assert_contains "$output" 'MCP catalog' "MCP reconciliation is planned"
assert_contains "$output" 'brew services start colima' "Colima service registration is planned"
assert_file_contains "${BOOTSTRAP_ROOT}/bootstrap" 'activate_bootstrap_runtime' "standalone commands activate mise runtimes"

help_output="$(bash "${BOOTSTRAP_ROOT}/bootstrap" --help)"
assert_contains "$help_output" 'kubernetes' "help documents Kubernetes command"
assert_contains "$help_output" '--dry-run' "help documents dry-run"
assert_contains "$help_output" '--only' "help documents phase selection"

clean_bin="${TEST_ROOT}/clean-bin"
mkdir -p "$clean_bin"
for command_name in uname sw_vers xcode-select; do
  cp "${TEST_ROOT}/bin/${command_name}" "${clean_bin}/${command_name}"
done
if HOME="$HOME" \
  PATH="${clean_bin}:/usr/bin:/bin:/usr/sbin:/sbin" \
  BOOTSTRAP_STATE_DIR="${TEST_ROOT}/clean-state" \
  bash "${BOOTSTRAP_ROOT}/bootstrap" --dry-run >/dev/null 2>&1; then
  pass "clean Mac dry-run succeeds before any package is installed"
else
  fail "clean Mac dry-run succeeds before any package is installed"
fi
TEST_COUNT=$((TEST_COUNT + 1))

manual="${BOOTSTRAP_ROOT}/docs/korean-manual.md"
assert_file_contains "$manual" '빠른 시작' "Korean manual has quick start"
assert_file_contains "$manual" 'MCP와 Figma' "Korean manual explains MCP and Figma"
assert_file_contains "$manual" 'Kubernetes' "Korean manual explains Kubernetes lab"
assert_file_contains "$manual" '문제 해결' "Korean manual has troubleshooting"

finish_tests
