## Shared AI developer environment

The machine bootstrap installs the same skills and MCP catalog for Codex,
Claude Code, Google Antigravity, VS Code, and GitHub Copilot. Prefer the shared
skills under `~/.agents/skills`. Never print, copy, or commit authentication
tokens.

### CodeGraph autonomous indexing

At the start of work in any Git repository, check whether `.codegraph/` exists
and whether its index is fresh relative to tracked source changes. If the index
is absent, stale, or incompatible with the installed CodeGraph version, run
`codegraph init -i` proactively without waiting for a separate user request.
Respect `.gitignore`, avoid secrets and generated build output, and report an
indexing error rather than deleting user data. Once indexed, use CodeGraph MCP
tools before broad file-reading or grep loops for architecture exploration.

### Ponytail

Apply the minimal-solution ladder from
`https://github.com/DietrichGebert/ponytail`: first decide whether code needs to
exist, then reuse project code, standard libraries, native platform features,
and installed dependencies before writing the smallest new implementation.
This never weakens security, accessibility, trust-boundary validation, or
data-loss protections.

### Project isolation

- Python projects use `uv` and a project-local `.venv`.
- Java and Node versions are pinned with `mise.toml`.
- Node package managers use Corepack and checked-in lock files.
- Go versions are pinned with `mise.toml`; dependencies use Go Modules.
- Rust versions are pinned with `mise.toml`; dependencies use Cargo workspaces
  and `Cargo.lock`.
- .NET and C# use a pinned SDK, solution-local projects, local tool manifests,
  and NuGet lock files.
- C and C++ use the Homebrew LLVM toolchain, CMake/Ninja build directories,
  and project-local Conan profiles and lock files.
- Do not install project dependencies into system language runtimes.
