# macOS AI Developer Bootstrap Design

## Goal

Provide a repeatable, idempotent bootstrap system for a new macOS developer
machine. It installs the requested AI development tools, shares MCP servers and
agent skills across supported clients, configures language isolation and a
modern shell, and verifies the resulting environment.

## Supported Systems

- macOS 14 or newer.
- Apple Silicon and Intel Macs.
- Interactive execution by a local administrator.
- Secrets and login state are never committed or copied into repository files.

## Architecture

The repository exposes one `bootstrap` command. A small POSIX-compatible entry
script performs platform checks and then runs focused Bash modules. Declarative
manifests hold Homebrew packages, casks, MCP definitions, and agent targets.
Adapters translate the common MCP catalog into each client's supported native
configuration or CLI commands.

The installer is safe to rerun. Every module checks current state, reports what
it changes, and supports dry-run execution. The main phases are:

1. preflight and Xcode Command Line Tools;
2. Homebrew and packages;
3. AI clients and VS Code;
4. language and project isolation;
5. shell and observability;
6. lightweight containers;
7. shared skills and MCP configuration;
8. optional interactive authentication;
9. verification and a machine-readable report.

## Command Interface

`./bootstrap` runs every non-authentication phase. It accepts:

- `--dry-run` to print mutations without making them;
- `--only <phase>` to run one comma-separated phase set;
- `--skip <phase>` to omit one comma-separated phase set;
- `--yes` to accept non-secret prompts;
- `--verbose` for diagnostic logging.

Related commands are:

- `./bootstrap auth` for interactive account and OAuth setup;
- `./bootstrap doctor` for read-only verification;
- `./bootstrap skills` to refresh the shared skills catalog;
- `./bootstrap mcp` to reconcile MCP configuration.

## Package Installation

Homebrew is installed with its official installer when absent and initialized
from `/opt/homebrew` on Apple Silicon or `/usr/local` on Intel. A Brewfile
installs:

- Git, GitHub CLI, Codex, Google Antigravity CLI, Claude Code, GitHub Copilot
  CLI, and Visual Studio Code;
- `mise`, `uv`, `pnpm`, and JDK tooling;
- `starship`, `zoxide`, `fzf`, `ripgrep`, `fd`, `bat`, `eza`, `direnv`, and
  `atuin`;
- `glances`, `btop`, `dust`, `duf`, and `procs`;
- Colima and the clients required for containerd/nerdctl workflows;
- jq and other small utilities required by the installer.

Official Homebrew formulae or casks are preferred. When a requested tool is not
available from Homebrew on a supported architecture, its vendor installer is
used only from the vendor's documented HTTPS endpoint.

## Language Isolation

`mise` owns default Java and Node versions and activates them per project.
Corepack activates package-manager shims and `pnpm` provides isolated global
tooling. `uv` owns Python installations and virtual environments. Shell
instructions require project-local `.venv`, `.tool-versions` or `mise.toml`,
and package-manager lock files rather than system-wide language packages.

## AI-Native Shell and Monitoring

A managed, clearly delimited block is added to `.zshrc`; reruns replace only
that block. It initializes Homebrew, mise, uv, direnv, Starship, zoxide, atuin,
and fzf without replacing unrelated user configuration. Useful aliases prefer
modern tools but retain standard command behavior. Glances and companion
monitoring tools are installed without enabling an always-running service.

## Lightweight Containers

Colima is configured with containerd and nerdctl, not Docker Desktop or Podman.
The default profile uses conservative CPU, memory, and disk values that the
user can override through environment variables. Starting the VM is explicit
unless the user requests autostart. The doctor command verifies both Colima and
nerdctl and, when the runtime is running, performs a lightweight connectivity
check.

## Shared Skills

The canonical user-level skill location is `${HOME}/.agents/skills`.
`find-skills` is installed explicitly from `vercel-labs/skills`. At refresh
time the installer discovers every repository listed on the skills.sh Official
page and every skill in all current Topic collections, deduplicates them, and
uses the official `skills` CLI to install them into the shared location for all
supported agents.

Because the remote catalog changes independently of this repository, the
refresh writes a lock/report containing source, resolved revision when
available, timestamp, success, and failure. A single unavailable third-party
skill does not erase already installed skills, but the overall command exits
nonzero and identifies every failed item. Anonymous CLI telemetry is disabled
by default. Existing unrelated skills are preserved.

## MCP Catalog and Client Adapters

The common catalog contains:

- Sequential Thinking;
- Time;
- DeepWiki;
- Context7;
- Memory;
- Ponytail from `DietrichGebert/ponytail`;
- CodeGraph from `colbymchenry/codegraph`;
- the official remote Figma MCP endpoint.

Catalog entries specify transport, command or URL, arguments, required
environment-variable names, and a health-check method. No secret value appears
in the catalog.

Adapters reconcile this catalog for:

- Codex CLI;
- Claude Code;
- Google Antigravity CLI;
- VS Code;
- GitHub Copilot CLI.

Where a client has a stable MCP management command, the adapter uses it.
Otherwise it performs a structured JSON/TOML merge, backs up an existing file,
and changes only server keys owned by this project. Unsupported servers are
reported rather than silently treated as installed.

Figma is registered everywhere the client supports remote HTTP MCP. Its OAuth
login remains interactive. The doctor output distinguishes “configured”,
“authentication required”, and “healthy”.

## CodeGraph Autonomous Indexing

Shared agent instructions state that an agent entering a repository must check
CodeGraph index freshness. If the index is missing, stale relative to the
working tree, or incompatible with the installed CodeGraph version, the agent
indexes the repository proactively without waiting for a separate user
instruction. It must avoid indexing ignored secrets, generated build outputs,
or paths excluded by the repository. Indexing failures are reported but do not
authorize destructive cleanup.

## Authentication and Security

The default bootstrap never asks for or persists API tokens. `bootstrap auth`
launches supported interactive login flows for GitHub, Codex, Claude,
Antigravity, Copilot, Figma, and any MCP requiring OAuth. Environment-variable
names may be documented, but their values remain in the user's chosen secret
manager or login keychain.

Downloaded scripts use TLS, strict curl failure flags, and vendor-owned URLs.
Configuration writes are backed up and atomic. Shell modules run with strict
error handling. Logs redact values associated with token, key, secret, and
authorization names.

## Error Handling and Recovery

Each phase records `changed`, `unchanged`, `skipped`, or `failed`. A required
foundation failure stops dependent phases. Independent MCP or skills failures
are collected so the final report is complete. The last report is written
under `.bootstrap-state/`, which is ignored by Git. Rerunning a phase is the
primary recovery mechanism.

The installer never removes user packages, MCP entries, skills, dotfiles, or
containers. Backups include timestamps and remain under a user-owned state
directory.

## Testing and Verification

Tests run without mutating the developer's real home directory. They inject a
temporary HOME, mock external executables, and cover:

- architecture and Homebrew prefix detection;
- phase selection and dry-run behavior;
- idempotent managed-block updates;
- manifest parsing and duplicate removal;
- structured MCP merges that preserve unrelated keys;
- skills discovery, deduplication, partial failures, and reporting;
- CodeGraph instruction presence;
- secret redaction;
- doctor success and failure reporting.

Static validation uses `bash -n`, ShellCheck when available, JSON/TOML parsing,
and a manifest-to-requirements audit. A live installation is intentionally not
run on the development machine during repository tests.

## Repository and Git Flow

The repository is initialized with `main` and `develop`. Work occurs on
`feature/*` branches and releases flow through `release/*` or `hotfix/*` as
appropriate. Conventional Commits are documented. Generated state, local
backups, credentials, and installed shared skills are excluded from Git.

## Success Criteria

On a supported clean Mac, one bootstrap run installs every requested tool and
configures every supported integration; a second run makes no unintended
changes. `bootstrap doctor` provides direct evidence for all fifteen requested
areas. Authentication-dependent checks explicitly say when user login is the
only remaining action. Tests prove configuration safety without modifying the
operator's current machine.
