#!/usr/bin/env bash

package_manifest_relative_path() {
  printf 'config/Brewfile\n'
}

package_manifest_path() {
  printf '%s/%s\n' "$BOOTSTRAP_ROOT" "$(package_manifest_relative_path)"
}

install_packages() {
  if ! command_exists brew; then
    if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
      log "DRY-RUN brew bundle --file $(package_manifest_path) --no-lock"
      record_result packages changed "planned Homebrew bundle reconciliation"
      return 0
    fi
    die "Homebrew is required before the packages phase"
    record_result packages failed "brew missing"
    return 1
  fi

  run brew bundle --file "$(package_manifest_path)" --no-lock
  record_result packages changed "Homebrew bundle reconciled"
}
