#!/usr/bin/env bash

set -u

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test_helper.sh"
setup_test_env
trap teardown_test_env EXIT

cat > "${TEST_ROOT}/bin/brew" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_BREW_LOG"
MOCK
chmod +x "${TEST_ROOT}/bin/brew"
export MOCK_BREW_LOG="${TEST_ROOT}/brew-services.log"

source "${BOOTSTRAP_ROOT}/lib/core.sh"
source "${BOOTSTRAP_ROOT}/lib/shell.sh"

BOOTSTRAP_DRY_RUN=0
configure_shell >/dev/null
configure_shell >/dev/null

zshrc="${HOME}/.zshrc"
assert_eq "1" "$(grep -c 'BEGIN macos-ai-bootstrap:ai-native-shell' "$zshrc")" "zsh integration is idempotent"

for marker in 'brew shellenv' 'mise activate zsh' 'direnv hook zsh' 'starship init zsh' 'zoxide init zsh' 'atuin init zsh' 'fzf --zsh' 'UV_PROJECT_ENVIRONMENT'; do
  assert_file_contains "$zshrc" "$marker" "zsh block includes ${marker}"
done

configure_containers >/dev/null
colima_config="${HOME}/.colima/_templates/default.yaml"
assert_file_contains "$MOCK_BREW_LOG" 'services start colima' "Colima is registered as a Homebrew service"
assert_file_contains "$colima_config" 'runtime: containerd' "Colima selects containerd"
assert_file_contains "$colima_config" 'cpu: 4' "Colima has conservative CPU default"
assert_file_contains "$colima_config" 'memory: 8' "Colima has conservative memory default"
assert_file_contains "$colima_config" 'enabled: false' "default Colima profile leaves Kubernetes off"

printf 'user-owned: true\n' > "$colima_config"
configure_containers >/dev/null
assert_file_contains "$colima_config" 'user-owned: true' "existing Colima template is preserved"

block_contents="$(cat "${BOOTSTRAP_ROOT}/config/zshrc.block")"
assert_contains "$block_contents" 'pnpm' "pnpm is activated in shell"
assert_contains "$block_contents" 'uv' "uv is activated in shell"
assert_contains "$block_contents" 'mise' "mise is activated in shell"

assert_eq "macos-ai-k8s" "$(kubernetes_profile_name)" "Kubernetes uses a dedicated profile"
assert_file_contains "${BOOTSTRAP_ROOT}/lib/shell.sh" 'go@latest' "Go toolchain is managed through mise"
assert_file_contains "${BOOTSTRAP_ROOT}/lib/shell.sh" 'rust@stable' "Rust toolchain is managed through mise"
assert_file_contains "${BOOTSTRAP_ROOT}/lib/shell.sh" 'dotnet@8' ".NET and C# toolchain is managed through mise"
assert_file_contains "${BOOTSTRAP_ROOT}/lib/shell.sh" 'mise activate bash' "mise runtimes are activated for the running bootstrap"
assert_file_contains "${BOOTSTRAP_ROOT}/lib/shell.sh" 'HOME}/.local/bin' "standalone bootstrap phases activate user-local tools"
assert_file_contains "${BOOTSTRAP_ROOT}/lib/shell.sh" 'mise exec node@24 -- corepack' "Corepack runs through the managed Node runtime"
assert_file_contains "${BOOTSTRAP_ROOT}/lib/shell.sh" "uv tool install --python 3.13 --force 'glances[all]'" "Glances installs with every optional extra"
assert_file_contains "${BOOTSTRAP_ROOT}/bin/nerdctl" 'colima nerdctl --' "user-local nerdctl wrapper delegates to Colima"
assert_file_contains "${HOME}/.local/bin/nerdctl" 'colima nerdctl --' "container phase installs the user-local nerdctl wrapper"
assert_file_contains "${BOOTSTRAP_ROOT}/config/AGENTS.shared.md" 'Go Modules' "shared guidance explains Go isolation"
assert_file_contains "${BOOTSTRAP_ROOT}/config/AGENTS.shared.md" 'Cargo' "shared guidance explains Rust isolation"
assert_file_contains "${BOOTSTRAP_ROOT}/config/AGENTS.shared.md" 'Conan' "shared guidance explains C and C++ isolation"
assert_file_contains "${BOOTSTRAP_ROOT}/config/AGENTS.shared.md" '.NET' "shared guidance explains .NET and C# isolation"

finish_tests
