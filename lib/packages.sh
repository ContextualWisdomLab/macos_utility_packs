#!/usr/bin/env bash

package_manifest_relative_path() {
  printf 'config/Brewfile\n'
}

package_manifest_path() {
  printf '%s/%s\n' "$BOOTSTRAP_ROOT" "$(package_manifest_relative_path)"
}

clear_verified_cli_quarantine() {
  local command_name="$1"
  local expected_team="$2"
  command_exists "$command_name" || return 0
  command_exists xattr || return 0
  command_exists codesign || return 0

  local executable signature
  executable="$(command -v "$command_name")"
  xattr -p com.apple.quarantine "$executable" >/dev/null 2>&1 || return 0
  signature="$(codesign -dv --verbose=2 "$executable" 2>&1)" || {
    log "keeping quarantine on ${command_name}: signature inspection failed"
    return 1
  }
  if ! printf '%s\n' "$signature" | grep -Fq "TeamIdentifier=${expected_team}" ||
    ! codesign --verify --strict "$executable" >/dev/null 2>&1; then
    log "keeping quarantine on ${command_name}: expected publisher signature is absent"
    return 1
  fi

  run xattr -d com.apple.quarantine "$executable"
  log "cleared quarantine on verified ${command_name} CLI (${expected_team})"
}

install_packages() {
  if ! command_exists brew; then
    if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
      log "DRY-RUN brew bundle --file $(package_manifest_path)"
      record_result packages changed "planned Homebrew bundle reconciliation"
      return 0
    fi
    die "Homebrew is required before the packages phase"
    record_result packages failed "brew missing"
    return 1
  fi

  run brew bundle --file "$(package_manifest_path)"
  # These signed command-line casks can retain a quarantine attribute that
  # causes a non-interactive first launch to be killed. Never clear it unless
  # the exact publisher TeamIdentifier and the code signature both verify.
  clear_verified_cli_quarantine claude Q6L2SF6YDW
  clear_verified_cli_quarantine agy EQHXZ8M8AV
  record_result packages changed "Homebrew bundle reconciled"
}
