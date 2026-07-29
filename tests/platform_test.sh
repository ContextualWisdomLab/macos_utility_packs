#!/usr/bin/env bash

set -u

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test_helper.sh"
setup_test_env
trap teardown_test_env EXIT

source "${BOOTSTRAP_ROOT}/lib/core.sh"
source "${BOOTSTRAP_ROOT}/lib/platform.sh"

assert_eq "/opt/homebrew" "$(brew_prefix arm64)" "Apple Silicon Homebrew prefix"
assert_eq "/usr/local" "$(brew_prefix x86_64)" "Intel Homebrew prefix"

if supported_macos_version 14.0; then
  pass "macOS 14 is supported"
else
  fail "macOS 14 is supported"
fi
TEST_COUNT=$((TEST_COUNT + 1))

if supported_macos_version 13.9; then
  fail "macOS below 14 is rejected"
else
  pass "macOS below 14 is rejected"
fi
TEST_COUNT=$((TEST_COUNT + 1))

if brew_prefix sparc >/dev/null 2>&1; then
  fail "unsupported architecture is rejected"
else
  pass "unsupported architecture is rejected"
fi
TEST_COUNT=$((TEST_COUNT + 1))

finish_tests
