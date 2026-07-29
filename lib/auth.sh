#!/usr/bin/env bash

confirm_auth() {
  if [[ "$BOOTSTRAP_YES" == "1" ]]; then
    return 0
  fi
  printf 'Start interactive account logins now? [y/N] ' >&2
  local answer
  read -r answer
  [[ "$answer" == "y" || "$answer" == "Y" ]]
}

run_auth() {
  if ! confirm_auth; then
    record_result auth skipped "user declined interactive authentication"
    return 0
  fi

  local failed=0
  command_exists gh && run gh auth login || failed=1
  command_exists codex && run codex login || failed=1
  command_exists claude && run claude auth login || failed=1
  command_exists agy && run agy || failed=1

  log "GitHub Copilot CLI: start 'copilot' and use /login if not already authenticated."
  log "Figma: open each client's MCP UI and authenticate the 'figma' remote server."

  if (( failed > 0 )); then
    record_result auth failed "one or more interactive login commands failed"
    return 1
  fi
  record_result auth changed "supported interactive login flows completed"
}
