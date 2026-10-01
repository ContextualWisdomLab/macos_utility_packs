#!/usr/bin/env bash

set -u

# shellcheck source=tests/test_helper.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test_helper.sh"
setup_test_env
trap teardown_test_env EXIT

mock_log="${TEST_ROOT}/npx.log"
cat > "${TEST_ROOT}/bin/npx" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_NPX_LOG"
exit 0
MOCK
chmod +x "${TEST_ROOT}/bin/npx"
export MOCK_NPX_LOG="$mock_log"

skills_list="${TEST_ROOT}/skills.tsv"
printf 'safe/repo\tsafe-skill\n' > "$skills_list"
export SKILLS_LIST_FILE="$skills_list"
export SKILLS_CANONICAL_DIR="${HOME}/.agents/skills"

# shellcheck source=lib/core.sh
source "${BOOTSTRAP_ROOT}/lib/core.sh"
# shellcheck source=lib/skills.sh
source "${BOOTSTRAP_ROOT}/lib/skills.sh"

malformed_blacklist="${TEST_ROOT}/malformed-blacklist.json"
printf '%s\n' '[{"names":["safe-skill"]}]' > "$malformed_blacklist"
missing_version_blacklist="${TEST_ROOT}/missing-version-blacklist.json"
printf '%s\n' '{"entries":[]}' > "$missing_version_blacklist"
unsupported_version_blacklist="${TEST_ROOT}/unsupported-version-blacklist.json"
printf '%s\n' '{"version":2,"entries":[]}' > "$unsupported_version_blacklist"
boolean_version_blacklist="${TEST_ROOT}/boolean-version-blacklist.json"
printf '%s\n' '{"version":true,"entries":[]}' > "$boolean_version_blacklist"
missing_blacklist="${TEST_ROOT}/missing-blacklist.json"
valid_blacklist="${TEST_ROOT}/valid-blacklist.json"
printf '%s\n' '{"version":1,"entries":[]}' > "$valid_blacklist"

for blacklist_case in \
  "$malformed_blacklist" \
  "$missing_version_blacklist" \
  "$unsupported_version_blacklist" \
  "$boolean_version_blacklist" \
  "$missing_blacklist"; do
  export SKILL_BLACKLIST_FILE="$blacklist_case"
  : > "$mock_log"
  if install_shared_skills >/dev/null 2>&1; then
    fail "invalid deny-list configuration fails the skills sync closed"
  else
    pass "invalid deny-list configuration fails the skills sync closed"
  fi
  TEST_COUNT=$((TEST_COUNT + 1))
  assert_eq "0" "$(grep -c -- '--skill safe-skill' "$mock_log" || true)" \
    "invalid deny-list configuration never reaches the installer"
  if skill_is_blacklisted safe-skill; then
    pass "invalid deny-list configuration blocks the direct candidate backstop"
  else
    fail "invalid deny-list configuration blocks the direct candidate backstop"
  fi
  TEST_COUNT=$((TEST_COUNT + 1))
  : > "$mock_log"
  direct_status=0
  (
    list_source_skills() { printf '%s\n' safe-skill; }
    install_one_skill safe/repo '*'
  ) >/dev/null 2>&1 || direct_status=$?
  assert_eq "2" "$direct_status" \
    "invalid deny-list configuration leaves no wildcard skill eligible"
  assert_eq "0" "$(grep -c -- '--skill safe-skill' "$mock_log" || true)" \
    "direct wildcard installation never bypasses an invalid deny list"
done

export SKILL_BLACKLIST_FILE="$valid_blacklist"
: > "$mock_log"
missing_python_status=0
(
  PATH="${TEST_ROOT}/without-python"
  list_source_skills() { printf '%s\n' safe-skill; }
  skill_conflicts_with_client_command() { return 1; }
  run_skills_add() { printf '%s\n' "$*" >> "$mock_log"; }
  install_one_skill safe/repo '*'
) >/dev/null 2>&1 || missing_python_status=$?
assert_eq "2" "$missing_python_status" \
  "missing Python leaves no wildcard skill eligible"
assert_eq "0" "$(grep -c -- '--skill safe-skill' "$mock_log" || true)" \
  "validator execution failure never reaches the installer"

validator_failure_bin="${TEST_ROOT}/validator-failure-bin"
mkdir -p "$validator_failure_bin"
cat > "${validator_failure_bin}/python3" <<'MOCK'
#!/usr/bin/env bash
# Model an unhandled Python exception, which exits with status 1.
exit 1
MOCK
chmod +x "${validator_failure_bin}/python3"
export SKILL_BLACKLIST_FILE="$valid_blacklist"
if PATH="${validator_failure_bin}:$PATH" skill_is_blacklisted safe-skill; then
  pass "validator runtime failure blocks the direct candidate backstop"
else
  fail "validator runtime failure blocks the direct candidate backstop"
fi
TEST_COUNT=$((TEST_COUNT + 1))

production_state="${TEST_ROOT}/production-state"
mkdir -p "$production_state" "${TEST_ROOT}/production-backups"
if HOME="$HOME" \
  PATH="$PATH" \
  BOOTSTRAP_ROOT="$BOOTSTRAP_ROOT" \
  BOOTSTRAP_STATE_DIR="$production_state" \
  BOOTSTRAP_BACKUP_DIR="${TEST_ROOT}/production-backups" \
  SKILLS_LIST_FILE="$skills_list" \
  SKILLS_CANONICAL_DIR="$SKILLS_CANONICAL_DIR" \
  SKILL_BLACKLIST_FILE="$malformed_blacklist" \
  MOCK_NPX_LOG="$mock_log" \
  bash -euo pipefail -c \
    'source "$BOOTSTRAP_ROOT/lib/core.sh"; source "$BOOTSTRAP_ROOT/lib/skills.sh"; install_shared_skills' \
    >/dev/null 2>&1; then
  fail "production errexit boundary rejects malformed deny-list configuration"
else
  pass "production errexit boundary rejects malformed deny-list configuration"
fi
TEST_COUNT=$((TEST_COUNT + 1))
assert_file_contains "${production_state}/results.jsonl" \
  '"phase":"skills","status":"failed","detail":"skill deny list invalid"' \
  "production errexit boundary records the deny-list failure before exit"

finish_tests
