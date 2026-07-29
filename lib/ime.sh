#!/usr/bin/env bash

configure_korean_ime() {
  local config_source="${BOOTSTRAP_ROOT}/config/ime.lua"
  local config_target="${HOME}/.config/macos-ai-bootstrap/ime.lua"
  local init_target="${HAMMERSPOON_INIT:-${HOME}/.hammerspoon/init.lua}"
  local begin="-- BEGIN macos-ai-bootstrap:sebeolsik-ime"
  local end="-- END macos-ai-bootstrap:sebeolsik-ime"

  [[ -f "$config_source" ]] || die "missing IME configuration: ${config_source}"
  if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
    log "DRY-RUN configure built-in Sebeolsik and Left Shift + Space in Hammerspoon"
    record_result ime changed "planned Hammerspoon IME configuration"
    return 0
  fi

  mkdir -p "$(dirname "$config_target")" "$(dirname "$init_target")"
  cp "$config_source" "$config_target"
  [[ -e "$init_target" ]] || : > "$init_target"
  backup_file "$init_target"

  local temporary
  temporary="$(mktemp "${TMPDIR:-/tmp}/hammerspoon-init.XXXXXX")"
  awk -v begin="$begin" -v end="$end" '
    $0 == begin { skipping=1; next }
    $0 == end { skipping=0; next }
    !skipping { print }
  ' "$init_target" > "$temporary"
  {
    cat "$temporary"
    printf '\n%s\n' "$begin"
    printf 'dofile(os.getenv("HOME") .. "/.config/macos-ai-bootstrap/ime.lua")\n'
    printf '%s\n' "$end"
  } > "${temporary}.new"
  mv "${temporary}.new" "$init_target"
  rm -f "$temporary"

  record_result ime changed "built-in 390 Sebeolsik Hammerspoon toggle configured"
}
