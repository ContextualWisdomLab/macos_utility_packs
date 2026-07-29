#!/usr/bin/env bash

set -u

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

for cask in codex antigravity-cli claude-code visual-studio-code copilot-cli passepartout hammerspoon; do
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

source "${BOOTSTRAP_ROOT}/lib/core.sh"
source "${BOOTSTRAP_ROOT}/lib/packages.sh"
assert_eq "config/Brewfile" "$(package_manifest_relative_path)" "package module uses repository Brewfile"

finish_tests
