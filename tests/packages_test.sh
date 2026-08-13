#!/usr/bin/env bash

set -u

# shellcheck source=tests/test_helper.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test_helper.sh"
setup_test_env
trap teardown_test_env EXIT

brewfile="${BOOTSTRAP_ROOT}/config/Brewfile"

for formula in git gh jq mise uv pnpm llvm cmake ninja conan colima kubectl helm k9s glances btop dust duf procs starship zoxide fzf ripgrep fd bat eza direnv atuin openvpn; do
  if grep -Eq "^brew \"${formula}\"" "$brewfile"; then
    pass "Brewfile includes formula ${formula}"
  else
    fail "Brewfile includes formula ${formula}"
  fi
  TEST_COUNT=$((TEST_COUNT + 1))
done

for cask in chatgpt claude codex antigravity-cli claude-code visual-studio-code copilot-cli passepartout hammerspoon; do
  if grep -Eq "^cask \"${cask}\"" "$brewfile"; then
    pass "Brewfile includes cask ${cask}"
  else
    fail "Brewfile includes cask ${cask}"
  fi
  TEST_COUNT=$((TEST_COUNT + 1))
done

contents="$(cat "$brewfile")"
assert_not_contains "$contents" 'docker-desktop' "Docker Desktop is excluded"
assert_not_contains "$contents" 'podman' "Podman is excluded"
assert_not_contains "$contents" 'codex-app' "deprecated Codex Desktop cask is excluded"

source "${BOOTSTRAP_ROOT}/lib/core.sh"
source "${BOOTSTRAP_ROOT}/lib/packages.sh"
assert_eq "config/Brewfile" "$(package_manifest_relative_path)" "package module uses repository Brewfile"
assert_not_contains "$(cat "${BOOTSTRAP_ROOT}/lib/packages.sh")" '--no-lock' "package module avoids removed Homebrew Bundle options"
assert_file_contains "${BOOTSTRAP_ROOT}/lib/packages.sh" "TeamIdentifier=\${expected_team}" "CLI quarantine removal requires the expected publisher"
assert_file_contains "${BOOTSTRAP_ROOT}/lib/packages.sh" 'codesign --verify --strict' "CLI quarantine removal requires a valid signature"
assert_file_contains "${BOOTSTRAP_ROOT}/lib/packages.sh" 'clear_verified_cli_quarantine claude Q6L2SF6YDW' "Claude publisher identity is pinned"
assert_file_contains "${BOOTSTRAP_ROOT}/lib/packages.sh" 'clear_verified_cli_quarantine agy EQHXZ8M8AV' "Antigravity publisher identity is pinned"

finish_tests
