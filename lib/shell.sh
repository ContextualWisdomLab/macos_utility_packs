#!/usr/bin/env bash

activate_bootstrap_runtime() {
  case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) export PATH="${HOME}/.local/bin:${PATH}" ;;
  esac
  if command_exists mise; then
    eval "$(mise activate bash)"
    hash -r
  fi
}

configure_languages() {
  if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
    log "DRY-RUN configure mise Node, Java, Go, Rust, .NET, uv, pnpm, and Conan"
    record_result languages changed "planned language toolchain configuration"
    return 0
  fi
  local failed=0

  if command_exists mise; then
    run mise use -g node@24 || failed=1
    run mise use -g java@temurin-21 || failed=1
    run mise use -g go@latest || failed=1
    run mise use -g rust@stable || failed=1
    run mise use -g dotnet@8 || failed=1
    # Make the newly installed runtimes available to later phases in this run.
    activate_bootstrap_runtime
  else
    log "mise is not installed; packages phase must complete first"
    failed=1
  fi

  if command_exists mise; then
    run mise exec node@24 -- corepack enable || failed=1
    run mise exec node@24 -- corepack prepare pnpm@latest --activate || failed=1
  else
    log "corepack is unavailable until Node 24 is active"
    failed=1
  fi

  if command_exists uv; then
    debug "uv available at $(command -v uv)"
  else
    log "uv is not installed; packages phase must complete first"
    failed=1
  fi

  if (( failed != 0 )); then
    record_result languages failed "one or more runtime managers unavailable"
    return 1
  fi
  record_result languages changed "mise Node, Java, Go, Rust, .NET; Corepack/pnpm; uv; Conan"
}

configure_monitoring() {
  if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
    log "DRY-RUN install Glances with all optional integrations through uv"
    record_result monitoring changed "planned glances[all] uv tool installation"
    return 0
  fi
  if ! command_exists uv; then
    log "uv is not installed; packages phase must complete first"
    record_result monitoring failed "uv missing for glances[all]"
    return 1
  fi

  # Homebrew supplies the base command and supporting system libraries. The
  # user-local uv tool takes PATH precedence and provides every Glances extra.
  run uv tool install --python 3.13 --force 'glances[all]'
  record_result monitoring changed "glances[all] installed as a user-local uv tool"
}

install_ai_awake() {
  local source_file="${BOOTSTRAP_ROOT}/bin/ai-awake"
  local target="${HOME}/.local/bin/ai-awake"
  [[ -f "$source_file" ]] || die "missing ai-awake wrapper: ${source_file}"
  if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
    log "DRY-RUN install ${target}"
  else
    mkdir -p "$(dirname "$target")"
    cp "$source_file" "$target"
    chmod +x "$target"
  fi
  record_result awake changed "process-scoped caffeinate wrapper installed"
}

configure_shell() {
  local block="${BOOTSTRAP_ROOT}/config/zshrc.block"
  [[ -f "$block" ]] || die "missing shell block: ${block}"
  managed_block "${HOME}/.zshrc" "ai-native-shell" "$block"
  record_result shell changed "managed .zshrc block reconciled"
}

configure_containers() {
  local source_file="${BOOTSTRAP_ROOT}/config/colima.yaml"
  local target="${HOME}/.colima/_templates/default.yaml"
  local nerdctl_source="${BOOTSTRAP_ROOT}/bin/nerdctl"
  local nerdctl_target="${HOME}/.local/bin/nerdctl"
  local failed=0
  [[ -f "$source_file" ]] || die "missing Colima template: ${source_file}"
  [[ -f "$nerdctl_source" ]] || die "missing nerdctl wrapper: ${nerdctl_source}"

  if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
    log "DRY-RUN install Colima containerd template at ${target}"
    log "DRY-RUN install user-local nerdctl wrapper at ${nerdctl_target}"
    log "DRY-RUN brew services start colima"
  else
    if [[ ! -e "$target" ]]; then
      mkdir -p "$(dirname "$target")"
      cp "$source_file" "$target"
    fi
    if [[ ! -f "$nerdctl_target" ]] || ! cmp -s "$nerdctl_source" "$nerdctl_target"; then
      mkdir -p "$(dirname "$nerdctl_target")"
      cp "$nerdctl_source" "$nerdctl_target"
      chmod +x "$nerdctl_target"
    fi

    if command_exists brew; then
      run brew services start colima || failed=1
      if (( failed == 0 )) && ! colima_runtime_is_containerd; then
        log "Colima is not running with the required containerd runtime"
        failed=1
      fi
    else
      log "Homebrew is unavailable; cannot register the Colima service"
      failed=1
    fi
  fi

  if (( failed != 0 )); then
    record_result containers failed "Colima service registration or containerd runtime verification failed"
    return 1
  fi
  record_result containers changed "Colima configured for containerd/nerdctl and brew service"
}

kubernetes_profile_name() {
  printf 'macos-ai-k8s\n'
}

configure_kubernetes() {
  if ! command_exists colima || ! command_exists kubectl; then
    die "Colima and kubectl are required for the Kubernetes profile"
    record_result kubernetes failed "Colima or kubectl missing"
    return 1
  fi

  local profile
  profile="$(kubernetes_profile_name)"
  run colima start \
    --profile "$profile" \
    --runtime containerd \
    --kubernetes \
    --cpu "${BOOTSTRAP_K8S_CPU:-4}" \
    --memory "${BOOTSTRAP_K8S_MEMORY:-8}" \
    --disk "${BOOTSTRAP_K8S_DISK:-40}"
  run kubectl cluster-info
  record_result kubernetes changed "on-demand Colima k3s profile ${profile} is ready"
}
