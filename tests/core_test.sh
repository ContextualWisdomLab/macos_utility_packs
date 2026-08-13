#!/usr/bin/env bash

set -u

# shellcheck source=tests/test_helper.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test_helper.sh"
setup_test_env
trap teardown_test_env EXIT

source "${BOOTSTRAP_ROOT}/lib/core.sh"

BOOTSTRAP_ONLY="packages,mcp"
BOOTSTRAP_SKIP=""
phase_selected packages
assert_eq "0" "$?" "selected phase returns success"
if phase_selected skills; then
  fail "unselected phase returns failure"
else
  pass "unselected phase returns failure"
  TEST_COUNT=$((TEST_COUNT + 1))
fi

BOOTSTRAP_ONLY=""
BOOTSTRAP_SKIP="skills,mcp"
if phase_selected mcp; then
  fail "skipped phase returns failure"
else
  pass "skipped phase returns failure"
  TEST_COUNT=$((TEST_COUNT + 1))
fi

BOOTSTRAP_DRY_RUN=1
run touch "${TEST_ROOT}/must-not-exist"
assert_eq "no" "$([[ -e "${TEST_ROOT}/must-not-exist" ]] && printf yes || printf no)" "dry-run suppresses mutations"

block="${TEST_ROOT}/block"
target="${TEST_ROOT}/zshrc"
printf 'export EXAMPLE=1\n' > "$block"
printf 'user-line\n' > "$target"
BOOTSTRAP_DRY_RUN=0
managed_block "$target" "test-block" "$block"
managed_block "$target" "test-block" "$block"
assert_eq "1" "$(grep -c 'BEGIN macos-ai-bootstrap:test-block' "$target")" "managed block is idempotent"
assert_file_contains "$target" "user-line" "managed block preserves unrelated content"

redacted="$(redact 'token=abc123 API_KEY=secret Authorization: Bearer xyz normal=value')"
assert_not_contains "$redacted" "abc123" "token value is redacted"
assert_not_contains "$redacted" "secret" "key value is redacted"
assert_not_contains "$redacted" "Bearer xyz" "authorization value is redacted"
assert_contains "$redacted" "normal=value" "non-secret text is preserved"

finish_tests
