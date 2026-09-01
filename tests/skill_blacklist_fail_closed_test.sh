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
missing_blacklist="${TEST_ROOT}/missing-blacklist.json"

for blacklist_case in "$malformed_blacklist" "$missing_blacklist"; do
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
done

finish_tests
