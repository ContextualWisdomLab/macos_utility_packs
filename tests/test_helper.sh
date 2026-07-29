#!/usr/bin/env bash

set -u

TEST_ROOT=""
TEST_COUNT=0
TEST_FAILURES=0
TEST_ORIGINAL_PATH="$PATH"

setup_test_env() {
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/macos-bootstrap-test.XXXXXX")"
  export HOME="${TEST_ROOT}/home"
  export BOOTSTRAP_STATE_DIR="${TEST_ROOT}/state"
  export BOOTSTRAP_BACKUP_DIR="${TEST_ROOT}/backups"
  export BOOTSTRAP_ROOT
  BOOTSTRAP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  mkdir -p "$HOME" "$BOOTSTRAP_STATE_DIR" "$BOOTSTRAP_BACKUP_DIR" "${TEST_ROOT}/bin"
  export PATH="${TEST_ROOT}/bin:${TEST_ORIGINAL_PATH}"
}

teardown_test_env() {
  if [[ -n "${TEST_ROOT:-}" && -d "$TEST_ROOT" ]]; then
    rm -rf "$TEST_ROOT"
  fi
}

fail() {
  printf 'not ok - %s\n' "$1" >&2
  TEST_FAILURES=$((TEST_FAILURES + 1))
}

pass() {
  printf 'ok - %s\n' "$1"
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  TEST_COUNT=$((TEST_COUNT + 1))
  if [[ "$expected" == "$actual" ]]; then
    pass "$message"
  else
    fail "${message}: expected [${expected}], got [${actual}]"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"
  TEST_COUNT=$((TEST_COUNT + 1))
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$message"
  else
    fail "${message}: missing [${needle}]"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"
  TEST_COUNT=$((TEST_COUNT + 1))
  if [[ "$haystack" != *"$needle"* ]]; then
    pass "$message"
  else
    fail "${message}: unexpectedly contained [${needle}]"
  fi
}

assert_file_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"
  assert_contains "$(cat "$file")" "$needle" "$message"
}

finish_tests() {
  printf '1..%d\n' "$TEST_COUNT"
  if (( TEST_FAILURES > 0 )); then
    printf '%d test(s) failed\n' "$TEST_FAILURES" >&2
    return 1
  fi
}
