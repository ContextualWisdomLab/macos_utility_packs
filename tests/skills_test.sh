#!/usr/bin/env bash

set -u

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test_helper.sh"
setup_test_env
trap teardown_test_env EXIT

discovery_output="$(
  python3 "${BOOTSTRAP_ROOT}/scripts/discover-skills.py" \
    --official-file "${BOOTSTRAP_ROOT}/tests/fixtures/official.html" \
    --topic-file "${BOOTSTRAP_ROOT}/tests/fixtures/topics.html"
)"

if python3 - "${BOOTSTRAP_ROOT}/scripts/discover-skills.py" <<'PY'
import runpy
import sys

module = runpy.run_path(sys.argv[1])
for action in (
    lambda: module["fetch_text"]("file:///etc/passwd"),
    lambda: module["CatalogRedirectHandler"]().redirect_request(
        None, None, 302, "", {}, "https://example.com/catalog"
    ),
):
    try:
        action()
    except ValueError:
        continue
    raise SystemExit(1)
PY
then
  pass "catalog fetch rejects unsafe initial and redirect URLs"
else
  fail "catalog fetch rejects unsafe initial and redirect URLs"
fi
TEST_COUNT=$((TEST_COUNT + 1))

assert_contains "$discovery_output" $'vercel-labs/skills\tfind-skills' "find-skills is discovered"
assert_contains "$discovery_output" $'openai/skills\t*' "all skills from an official repository are discovered"
assert_contains "$discovery_output" $'obra/superpowers\tsystematic-debugging' "topic skill is discovered"
assert_contains "$discovery_output" $'vercel/next.js\t*' "retired Next skills migrate to the current official source"
assert_not_contains "$discovery_output" 'vercel-labs/next-skills' "retired Next skills source is not installed"
assert_contains "$discovery_output" $'flutter/agent-plugins\t*' "Flutter skills migrate to the current official source"
assert_not_contains "$discovery_output" 'stripe/com' "unavailable retired sources are not treated as installable"
assert_eq "0" "$(printf '%s\n' "$discovery_output" | grep -c $'vercel-labs/skills\tweb-design-guidelines')" "official wildcard deduplicates topic entries"
assert_not_contains "$discovery_output" $'agents/codex\t*' "navigation routes are not treated as official repositories"
assert_not_contains "$discovery_output" $'agent/codex\t*' "singular agent routes are not treated as official repositories"

mock_log="${TEST_ROOT}/npx.log"
cat > "${TEST_ROOT}/bin/npx" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_NPX_LOG"
while IFS= read -r _line; do :; done
if [[ "$*" == *"bad/repo"* ]]; then
  exit 17
fi
if [[ "$*" == *"already/repo"* && "$*" == *"--list"* ]]; then
  printf '│    existing-one\n'
  exit 0
fi
if [[ "$*" == *"renamed/repo"* && "$*" == *"--list"* ]]; then
  printf '│    mcp\n│    current-skill\n'
  exit 0
fi
if [[ "$*" == *"conflicting/repo"* && "$*" == *"--list"* ]]; then
  printf '│    mcp\n│    claude\n│    codex\n│    grok\n│    build\n'
  exit 0
fi
if [[ "$*" == *"renamed/repo"* && "$*" == *"--skill old-name"* ]]; then
  exit 18
fi
MOCK
chmod +x "${TEST_ROOT}/bin/npx"
export MOCK_NPX_LOG="$mock_log"

mkdir -p "${HOME}/.agents/skills/find-skills" "${HOME}/.agents/skills/existing-one"
touch "${HOME}/.agents/skills/find-skills/SKILL.md"
touch "${HOME}/.agents/skills/existing-one/SKILL.md"
cat > "${HOME}/skills-lock.json" <<'JSON'
{
  "version": 1,
  "skills": {
    "find-skills": {
      "source": "vercel-labs/skills"
    },
    "existing-one": {
      "source": "already/repo"
    }
  }
}
JSON

skills_list="${TEST_ROOT}/skills.tsv"
printf 'vercel-labs/skills\tfind-skills\nalready/repo\t*\nopenai/skills\tdocs\nrenamed/repo\told-name\nbad/repo\tbroken-skill\nconflicting/repo\tmcp\nconflicting/repo\tclaude\nconflicting/repo\tcodex\nconflicting/repo\tgrok\nconflicting/repo\tbuild\nconflicting/repo\t*\n' > "$skills_list"
export SKILLS_LIST_FILE="$skills_list"
export SKILLS_CANONICAL_DIR="${HOME}/.agents/skills"

source "${BOOTSTRAP_ROOT}/lib/core.sh"
source "${BOOTSTRAP_ROOT}/lib/skills.sh"

if install_shared_skills >/dev/null 2>&1; then
  fail "partial installation failure returns nonzero"
else
  pass "partial installation failure returns nonzero"
fi
TEST_COUNT=$((TEST_COUNT + 1))

npx_calls="$(cat "$mock_log")"
assert_not_contains "$npx_calls" 'vercel-labs/skills --skill find-skills' "installed named skill is not reinstalled"
assert_contains "$npx_calls" 'already/repo --skill existing-one' "partial wildcard lock does not suppress full-source reconciliation"
assert_contains "$npx_calls" '--agent universal' "shared universal agent target is selected"
assert_contains "$npx_calls" '--agent codex' "Codex skill target is selected"
assert_contains "$npx_calls" '--agent claude-code' "Claude skill target is selected"
assert_contains "$npx_calls" '--agent antigravity-cli' "Antigravity CLI target is selected"
assert_contains "$npx_calls" '--agent github-copilot' "Copilot skill target is selected"
assert_contains "$npx_calls" 'renamed/repo --skill current-skill' "stale topic names fall back to current source skills"
assert_not_contains "$npx_calls" 'renamed/repo --skill mcp' "wildcard sources exclude MCP skill"
assert_contains "$npx_calls" 'conflicting/repo --list' "all-conflicting wildcard sources are inspected"
assert_not_contains "$npx_calls" 'conflicting/repo --skill' "client-command skill names are not installed"

report="${BOOTSTRAP_STATE_DIR}/skills-report.json"
assert_file_contains "$report" '"failed": 1' "failure count is reported"
assert_file_contains "$report" '"installed": 3' "new, wildcard, and fallback installations are reported"
assert_file_contains "$report" '"skipped": 7' "installed and conflicting entries are skipped"
assert_file_contains "$report" '"skill": "broken-skill"' "failed skill is named"

finish_tests
