#!/usr/bin/env bash

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
    eval "$(mise activate bash)"
    hash -r
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
  [[ -f "$source_file" ]] || die "missing Colima template: ${source_file}"

  if [[ -e "$target" ]]; then
    record_result containers unchanged "existing Colima template preserved"
    return 0
  fi
  if [[ "$BOOTSTRAP_DRY_RUN" == "1" ]]; then
    log "DRY-RUN install Colima containerd template at ${target}"
  else
    mkdir -p "$(dirname "$target")"
    cp "$source_file" "$target"
  fi
  record_result containers changed "Colima configured for containerd/nerdctl"
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
