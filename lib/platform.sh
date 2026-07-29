#!/usr/bin/env bash

detect_arch() {
  uname -m
}

brew_prefix() {
  local architecture="${1:-$(detect_arch)}"
  case "$architecture" in
    arm64) printf '/opt/homebrew\n' ;;
    x86_64) printf '/usr/local\n' ;;
    *) return 1 ;;
  esac
}

supported_macos_version() {
  local version="$1"
  local major="${version%%.*}"
  [[ "$major" =~ ^[0-9]+$ ]] && (( major >= 14 ))
}

preflight() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    die "this bootstrap supports macOS only"
    record_result preflight failed "non-macOS platform"
    return 1
  fi

  local architecture
  architecture="$(detect_arch)"
  if ! brew_prefix "$architecture" >/dev/null; then
    die "unsupported architecture: ${architecture}"
    record_result preflight failed "unsupported architecture"
    return 1
  fi

  local version
  version="$(sw_vers -productVersion)"
  if ! supported_macos_version "$version"; then
    die "macOS 14 or newer is required; found ${version}"
    record_result preflight failed "unsupported macOS ${version}"
    return 1
  fi

  if ! xcode-select -p >/dev/null 2>&1; then
    if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
      log "DRY-RUN xcode-select --install"
    else
      xcode-select --install
      die "finish the Xcode Command Line Tools installation, then rerun bootstrap"
      record_result preflight failed "Xcode Command Line Tools installation pending"
      return 1
    fi
  fi

  record_result preflight unchanged "macOS ${version} ${architecture}"
}

activate_homebrew() {
  local prefix
  prefix="$(brew_prefix)"
  if [[ -x "${prefix}/bin/brew" ]]; then
    eval "$("${prefix}/bin/brew" shellenv)"
  fi
}

install_homebrew() {
  if command_exists brew; then
    activate_homebrew
    record_result homebrew unchanged "$(brew --version | head -n 1)"
    return 0
  fi

  if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
    log "DRY-RUN install Homebrew from official installer"
    record_result homebrew changed "planned official Homebrew installation"
    return 0
  fi

  local installer
  installer="$(mktemp "${TMPDIR:-/tmp}/homebrew-install.XXXXXX")"
  curl --proto '=https' --tlsv1.2 -fsSLo "$installer" \
    https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
  NONINTERACTIVE=1 /bin/bash "$installer"
  rm -f "$installer"
  activate_homebrew
  command_exists brew || die "Homebrew installation did not provide brew"
  record_result homebrew changed "$(brew --version | head -n 1)"
}
