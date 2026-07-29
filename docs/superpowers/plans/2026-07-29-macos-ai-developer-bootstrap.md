# macOS AI Developer Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an idempotent macOS bootstrap command that installs and verifies the requested AI developer toolchain, shared MCP catalog, shared agent skills, shell, language, monitoring, and lightweight container environment.

**Architecture:** A strict Bash orchestrator loads small phase modules and declarative JSON manifests. Configuration mutations are isolated behind reusable managed-block and structured-merge helpers, while read-only doctor checks map directly to all twenty requirements.

**Tech Stack:** Bash 3.2-compatible shell, Homebrew Bundle, jq, Node-based skills CLI, Bats-compatible shell tests without a Bats dependency, JSON/TOML client configuration, Markdown documentation.

## Global Constraints

- Support macOS 14 or newer on Apple Silicon and Intel.
- Never store secrets or authentication state in repository files.
- Preserve unrelated user configuration, skills, packages, and containers.
- Default installation excludes interactive authentication.
- Use Colima with containerd and nerdctl; do not install Docker Desktop or Podman.
- Provide a separate, on-demand Colima Kubernetes profile.
- Install Passepartout/OpenVPN and a built-in Sebeolsik 390 toggle via Hammerspoon.
- Keep the Mac awake only for the lifetime of an `ai-awake` child process.
- Cover Python, Java, Node, Go, Rust, .NET/C#, and C/C++ with isolated tooling.
- Keep `${HOME}/.agents/skills` as the canonical shared skill directory.
- CodeGraph instructions must require autonomous indexing when absent or stale.
- Every mutation must support dry-run behavior and safe reruns.

## File Structure

- `bootstrap`: public command dispatcher and option parser.
- `lib/core.sh`: logging, command execution, selection, state, and redaction.
- `lib/platform.sh`: macOS, architecture, Xcode tools, and Homebrew setup.
- `lib/packages.sh`: Brewfile and requested package installation.
- `lib/shell.sh`: managed zsh block, language manager activation, and container template.
- `lib/ime.sh`: non-destructive Hammerspoon and Sebeolsik integration.
- `lib/skills.sh`: skills.sh discovery, deduplication, installation, and reporting.
- `lib/mcp.sh`: common MCP catalog reconciliation and client adapters.
- `lib/auth.sh`: explicit interactive authentication flows.
- `lib/doctor.sh`: requirement-oriented read-only health checks.
- `config/Brewfile`: formulas and casks.
- `config/mcp-servers.json`: secret-free common MCP catalog.
- `config/agent-targets.json`: supported client capabilities and locations.
- `bin/ai-awake`: process-scoped macOS sleep-prevention wrapper.
- `docs/한국어-매뉴얼.md`: complete Korean operator manual.
- `config/zshrc.block`: managed AI-native shell configuration.
- `config/AGENTS.shared.md`: shared behavior including CodeGraph indexing.
- `scripts/discover-skills.mjs`: official/topic page discovery.
- `tests/test_helper.sh`: temporary HOME, mocks, and assertions.
- `tests/*.sh`: isolated executable test suites.
- `scripts/test`: complete local validation entry point.
- `README.md`: operation, security, authentication, and recovery guide.
- `.gitignore`: generated state, credentials, and local artifacts.

---

### Task 1: Command Skeleton and Safe Core

**Files:**
- Create: `bootstrap`
- Create: `lib/core.sh`
- Create: `.gitignore`
- Create: `tests/test_helper.sh`
- Create: `tests/core_test.sh`
- Create: `scripts/test`

**Interfaces:**
- Produces: `run`, `command_exists`, `phase_selected`, `managed_block`, `redact`, `record_result`, and the `BOOTSTRAP_*` runtime variables used by every phase.
- Consumes: no project code.

- [ ] **Step 1: Write failing core tests**

Test phase selection, dry-run command suppression, idempotent managed blocks, and token redaction using a temporary HOME and mock executable directory.

- [ ] **Step 2: Run the core test and observe failure**

Run: `bash tests/core_test.sh`
Expected: nonzero because `lib/core.sh` and `bootstrap` do not exist.

- [ ] **Step 3: Implement the dispatcher and core helpers**

Parse `install`, `auth`, `doctor`, `skills`, and `mcp`; accept `--dry-run`, `--only`, `--skip`, `--yes`, and `--verbose`; write phase results as JSON Lines under `${BOOTSTRAP_STATE_DIR}`; never evaluate command strings.

- [ ] **Step 4: Run syntax and core tests**

Run: `bash -n bootstrap lib/core.sh && bash tests/core_test.sh`
Expected: all assertions pass.

- [ ] **Step 5: Commit**

```bash
git add bootstrap lib/core.sh .gitignore tests/test_helper.sh tests/core_test.sh scripts/test
git commit -m "feat: add safe bootstrap command core"
```

### Task 2: Platform, Homebrew, and Package Manifest

**Files:**
- Create: `lib/platform.sh`
- Create: `lib/packages.sh`
- Create: `config/Brewfile`
- Create: `tests/platform_test.sh`
- Create: `tests/packages_test.sh`
- Modify: `bootstrap`

**Interfaces:**
- Consumes: `run`, `command_exists`, `record_result`.
- Produces: `detect_arch`, `brew_prefix`, `preflight`, `install_homebrew`, and `install_packages`.

- [ ] **Step 1: Write failing platform and manifest tests**

Cover `arm64 -> /opt/homebrew`, `x86_64 -> /usr/local`, macOS version rejection below 14, required formula/cask presence, and explicit Docker Desktop/Podman absence.

- [ ] **Step 2: Run tests and observe failure**

Run: `bash tests/platform_test.sh && bash tests/packages_test.sh`
Expected: nonzero because platform and package modules are absent.

- [ ] **Step 3: Implement platform and package phases**

Use `sw_vers`, `uname`, and `xcode-select`; install Homebrew only from `https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh`; invoke `brew bundle --file config/Brewfile`; provide official fallback installers only where the manifest documents them.

- [ ] **Step 4: Run focused tests**

Run: `bash -n lib/platform.sh lib/packages.sh && bash tests/platform_test.sh && bash tests/packages_test.sh`
Expected: all assertions pass.

- [ ] **Step 5: Commit**

```bash
git add bootstrap lib/platform.sh lib/packages.sh config/Brewfile tests/platform_test.sh tests/packages_test.sh
git commit -m "feat: install platform foundations and developer packages"
```

### Task 3: Language, Shell, Monitoring, and Containers

**Files:**
- Create: `lib/shell.sh`
- Create: `config/zshrc.block`
- Create: `config/colima.yaml`
- Create: `tests/shell_test.sh`
- Modify: `bootstrap`

**Interfaces:**
- Consumes: `managed_block`, `run`, `record_result`, package commands.
- Produces: `configure_languages`, `configure_shell`, `configure_containers`,
  `configure_kubernetes`, and `install_ai_awake`.

- [ ] **Step 1: Write failing shell tests**

Verify the managed zsh block initializes Homebrew for both architectures, mise, uv, Corepack/pnpm, direnv, Starship, zoxide, atuin, and fzf exactly once; verify the Colima template selects containerd and contains configurable resource defaults.

- [ ] **Step 2: Run test and observe failure**

Run: `bash tests/shell_test.sh`
Expected: nonzero because the shell module and templates are absent.

- [ ] **Step 3: Implement shell, language, and container configuration**

Install Node 24 LTS, Temurin JDK 21, Go, Rust, and .NET 8 through mise,
activate Corepack, keep Python environments project-local through uv, add the
delimited zsh block and process-scoped awake wrapper, and copy non-autostart
Colima templates without overwriting an existing user profile.

- [ ] **Step 4: Run focused tests twice**

Run: `bash tests/shell_test.sh && bash tests/shell_test.sh`
Expected: both runs pass and the second produces no duplicate block.

- [ ] **Step 5: Commit**

```bash
git add bootstrap lib/shell.sh config/zshrc.block config/colima.yaml tests/shell_test.sh
git commit -m "feat: configure isolated runtimes and AI native shell"
```

### Task 4: Dynamic Shared Skills

**Files:**
- Create: `lib/skills.sh`
- Create: `scripts/discover-skills.mjs`
- Create: `tests/fixtures/official.html`
- Create: `tests/fixtures/topics.html`
- Create: `tests/skills_test.sh`
- Modify: `bootstrap`

**Interfaces:**
- Consumes: `run`, `record_result`, Node 22+, `npx skills`.
- Produces: `discover_skill_sources`, `install_shared_skills`, and `${BOOTSTRAP_STATE_DIR}/skills-report.json`.

- [ ] **Step 1: Write failing discovery and failure-report tests**

Use local HTML fixtures to prove repository extraction and deduplication. Mock `npx` to prove `find-skills` is explicit, `${HOME}/.agents/skills` is selected, existing skills survive, and one failed source makes the command nonzero with a complete report.

- [ ] **Step 2: Run test and observe failure**

Run: `bash tests/skills_test.sh`
Expected: nonzero because the discovery script and module are absent.

- [ ] **Step 3: Implement runtime discovery and installation**

Fetch `https://skills.sh/official` and all topic links from `https://skills.sh/topic`, parse canonical GitHub sources, deduplicate deterministically, install with telemetry disabled, and atomically publish the JSON report.

- [ ] **Step 4: Run fixture-based tests**

Run: `bash tests/skills_test.sh`
Expected: all assertions pass without network access.

- [ ] **Step 5: Commit**

```bash
git add bootstrap lib/skills.sh scripts/discover-skills.mjs tests/fixtures tests/skills_test.sh
git commit -m "feat: synchronize shared official agent skills"
```

### Task 5: MCP Catalog, Agent Adapters, and CodeGraph Policy

**Files:**
- Create: `config/mcp-servers.json`
- Create: `config/agent-targets.json`
- Create: `config/AGENTS.shared.md`
- Create: `lib/mcp.sh`
- Create: `scripts/merge-json.mjs`
- Create: `tests/mcp_test.sh`
- Modify: `bootstrap`

**Interfaces:**
- Consumes: `run`, `managed_block`, `record_result`, jq/Node, installed client CLIs.
- Produces: `configure_mcp`, `configure_agent_instructions`, client-specific configuration merges, and timestamped backups.

- [ ] **Step 1: Write failing catalog and merge tests**

Assert all eight MCP entries exist; every target includes Codex, Claude, Antigravity, VS Code, and Copilot; unrelated JSON keys survive; reruns are byte-stable; Figma is remote; CodeGraph policy explicitly requires autonomous freshness checks and indexing.

- [ ] **Step 2: Run test and observe failure**

Run: `bash tests/mcp_test.sh`
Expected: nonzero because catalog, merger, and module are absent.

- [ ] **Step 3: Implement catalog and adapters**

Use documented client commands where stable and structured file adapters otherwise. Keep environment variable placeholders symbolic. Back up an existing file before its first changed write and install shared instructions in `${HOME}/.agents/AGENTS.md` as a managed block.

- [ ] **Step 4: Run focused tests**

Run: `bash tests/mcp_test.sh`
Expected: catalog coverage, preservation, idempotence, Figma, and CodeGraph checks pass.

- [ ] **Step 5: Commit**

```bash
git add bootstrap config/mcp-servers.json config/agent-targets.json config/AGENTS.shared.md lib/mcp.sh scripts/merge-json.mjs tests/mcp_test.sh
git commit -m "feat: share MCP servers across AI developer clients"
```

### Task 6: Authentication and Requirement-Oriented Doctor

**Files:**
- Create: `lib/auth.sh`
- Create: `lib/doctor.sh`
- Create: `config/requirements.json`
- Create: `tests/doctor_test.sh`
- Modify: `bootstrap`

**Interfaces:**
- Consumes: every installed command and configuration artifact.
- Produces: `run_auth`, `run_doctor`, human-readable status, `${BOOTSTRAP_STATE_DIR}/doctor.json`, and requirement IDs `REQ-01` through `REQ-20`.

- [ ] **Step 1: Write failing doctor tests**

Mock commands and configs to prove all twenty requirement IDs appear, missing binaries fail, authentication-required is distinct from missing configuration, and doctor never invokes a mutating command.

- [ ] **Step 2: Run test and observe failure**

Run: `bash tests/doctor_test.sh`
Expected: nonzero because the modules and requirements map are absent.

- [ ] **Step 3: Implement explicit auth and read-only doctor**

Auth invokes only interactive vendor login commands after confirmation. Doctor checks binaries, Homebrew state, shared skill count/report, MCP entries per client, Figma registration, runtime managers, zsh managed block, monitors, Colima/containerd, Git, and Git Flow branches.

- [ ] **Step 4: Run focused tests**

Run: `bash tests/doctor_test.sh`
Expected: all twenty mapped checks pass in the complete fixture and fail precisely in incomplete fixtures.

- [ ] **Step 5: Commit**

```bash
git add bootstrap lib/auth.sh lib/doctor.sh config/requirements.json tests/doctor_test.sh
git commit -m "feat: add authentication flows and bootstrap doctor"
```

### Task 7: Documentation and End-to-End Safety

**Files:**
- Create: `README.md`
- Create: `CONTRIBUTING.md`
- Create: `SECURITY.md`
- Create: `tests/integration_test.sh`
- Modify: `scripts/test`

**Interfaces:**
- Consumes: complete public command.
- Produces: operator documentation and a temporary-HOME end-to-end dry run.

- [ ] **Step 1: Write failing integration audit**

Run bootstrap in dry-run mode with mocked platform/package/client commands; assert every phase is visited, no real HOME file changes, the report is valid JSON, and repeated execution is stable.

- [ ] **Step 2: Run test and observe failure**

Run: `bash tests/integration_test.sh`
Expected: failures identify missing orchestration or documentation.

- [ ] **Step 3: Write operator and contributor documentation**

Document prerequisites, quick start, phase controls, auth, secret handling, client limitations, skills volume and network cost, Colima behavior, recovery, doctor interpretation, Git Flow, and Conventional Commits.

- [ ] **Step 4: Run the complete validation suite**

Run: `scripts/test`
Expected: Bash syntax, JSON parsing, every test suite, requirement audit, and optional ShellCheck all pass.

- [ ] **Step 5: Commit**

```bash
git add README.md CONTRIBUTING.md SECURITY.md tests/integration_test.sh scripts/test
git commit -m "docs: document and verify macOS bootstrap workflow"
```

### Task 8: Completion Audit

**Files:**
- Modify only files implicated by audit findings.

**Interfaces:**
- Consumes: original twenty requirements, design, code, tests, and Git state.
- Produces: direct evidence for every requirement and a clean tested feature branch.

- [ ] **Step 1: Run full validation from a clean temporary HOME**

Run: `scripts/test`
Expected: zero exit status with no writes outside the temporary test directories.

- [ ] **Step 2: Run static and manifest audits**

Run: `bash -n bootstrap lib/*.sh tests/*.sh scripts/test && jq empty config/*.json && git diff --check`
Expected: zero exit status.

- [ ] **Step 3: Map evidence to all requirements**

Run: `./bootstrap doctor --dry-run` and inspect `config/requirements.json`, `config/Brewfile`, `config/mcp-servers.json`, the shared instruction template, and tests.
Expected: REQ-01 through REQ-20 each have implementation and verification evidence.

- [ ] **Step 4: Inspect Git Flow and working tree**

Run: `git branch --list && git log --oneline --decorate -10 && git status --short`
Expected: `main`, `develop`, and `feature/bootstrap-automation` exist; only intentional changes remain.

- [ ] **Step 5: Commit audit fixes if any**

```bash
git add bootstrap lib config scripts tests README.md CONTRIBUTING.md SECURITY.md
git commit -m "fix: close bootstrap completion audit gaps"
```
