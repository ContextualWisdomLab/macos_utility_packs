#!/usr/bin/env bash

set -u

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test_helper.sh"
setup_test_env
trap teardown_test_env EXIT

source "${BOOTSTRAP_ROOT}/lib/core.sh"
source "${BOOTSTRAP_ROOT}/lib/ime.sh"

printf '%s\n' '-- user-owned setting' > "${HOME}/init.lua"
export HAMMERSPOON_INIT="${HOME}/init.lua"
BOOTSTRAP_DRY_RUN=0
configure_korean_ime >/dev/null
configure_korean_ime >/dev/null

assert_file_contains "$HAMMERSPOON_INIT" '-- user-owned setting' "IME setup preserves user Hammerspoon settings"
assert_eq "1" "$(grep -c 'BEGIN macos-ai-bootstrap:sebeolsik-ime' "$HAMMERSPOON_INIT")" "IME Hammerspoon block is idempotent"

ime_config="${HOME}/.config/macos-ai-bootstrap/ime.lua"
assert_file_contains "$ime_config" '3-Set Korean (390)' "built-in 390 Sebeolsik is the default"
assert_file_contains "$ime_config" 'keyCode == 56' "IME tracks the left Shift key"
assert_file_contains "$ime_config" 'keyCode ~= 49' "IME isolates Space events"
assert_file_contains "$ime_config" 'spaceChordActive' "IME suppresses repeat and the matching Space key-up"
assert_file_contains "$ime_config" 'hs.keycodes.setMethod' "IME toggles the macOS input method"
assert_file_contains "$ime_config" 'MACOS_AI_KOREAN_INPUT_METHOD' "IME method is configurable"

assert_file_contains "${BOOTSTRAP_ROOT}/docs/한국어-매뉴얼.md" '세벌식' "Korean manual explains Sebeolsik"
assert_file_contains "${BOOTSTRAP_ROOT}/docs/한국어-매뉴얼.md" 'Left Shift + Space' "Korean manual explains requested shortcut"

finish_tests
