# ADR-0002: Treat Grok Build as a first-class bootstrap client

- Status: Proposed
- Date: 2026-09-07
- Deciders: macos_utility_packs maintainers
- Related: [ADR-0001](ADR-0001-bootstrap-boundaries.md)

## Context

The workstation bootstrap already reconciles MCP catalogs, shared agent
instructions, Ponytail plugins, and doctor evidence for Codex, Claude Code,
Antigravity, VS Code, and Copilot CLI. Grok Build (`grok`, cask `grok-build`)
was present on operator machines and in the skill-name conflict list, but
`develop@2368ed62937abfabb159c23aa52b81dde58b3dbe` did not write
`~/.grok/rules/AGENTS.md`, merge `~/.grok/config.toml`, install Grok plugins,
or fail doctor when those surfaces were missing.

Live Grok configuration uses the same `[mcp_servers.<name>]` TOML tables as
Codex (xAI, 2026a). Grok always scans `$GROK_HOME/rules/*.md` and
`~/.grok/hooks/*.json` (xAI, 2026b, 2026c). Plugin discovery auto-loads
`hooks/hooks.json` only; Ponytail ships `hooks/claude-codex-hooks.json`.
`codegraph install --target` does not list Grok. Homebrew formula `grok` is
Jordan Sissel's regex tool (Homebrew, 2026a); the xAI CLI is cask
`grok-build` (Homebrew, 2026b), signed `TeamIdentifier=5Y6N3AJ54S`.

Customer gap: an operator who runs `./bootstrap` still gets a Grok TUI that
lacks the shared MCP catalog, CodeGraph prompt-hook, Ponytail SessionStart
hooks, and the same AGENTS.md contract other clients receive.

## Decision

In the context of local macOS AI-workstation bootstrap, facing a Grok TUI
that consumed Claude-compat copies instead of native surfaces, we decided
for a `grok-cli` adapter that reuses `scripts/merge-codex-mcp.py` against
`~/.grok/config.toml`, writes `~/.grok/rules/AGENTS.md` and
`~/.grok/hooks/codegraph.json`, installs Ponytail with `--trust`, and links
`hooks/hooks.json`, and against installing Homebrew formula `grok`, calling
`grok mcp add` (OAuth), adding a fake `codegraph install --target=grok`, or
mirroring skills into `~/.grok/skills`, to achieve one catalog and one
doctor contract for every supported client, accepting that Grok remains
unavailable until `grok-build` is installed and that CodeGraph's installer
does not own the Grok MCP stanza.

## Alternatives considered

1. **Call `grok mcp add` like Claude.** Rejected: Codex already avoided CLI
   add during install because it can start OAuth. Grok's TOML schema matches
   the existing merger.
2. **Symlink `~/.grok/rules/AGENTS.md` and hooks to Codex/Claude homes.**
   Rejected: couples client homes; Grok natively loads its own rules and
   hook directories.
3. **Add Homebrew formula `grok`.** Rejected: name collision with an
   unrelated regex tool that Homebrew will disable on 2027-01-11.
4. **Wait for CodeGraph to grow a Grok target.** Rejected: the catalog TOML
   merge already registers `codegraph serve --mcp`; duplicating installer
   flags would invent an unsupported contract.

## Consequences

- Positive: `./bootstrap mcp`, `instructions`, `extensions`, `packages`,
  `auth`, and `doctor` treat Grok as a named client. Doctor `REQ-22` plus
  REQ-08/REQ-10 fail closed when Grok evidence is missing.
- Negative: machines without `grok-build` fail doctor until the cask is
  installed. Ponytail `hooks/hooks.json` is a bootstrap-owned symlink that
  `grok plugin update ponytail` may drop; extensions must recreate it.
- Neutral: shared skills stay in `~/.agents/skills`, which Grok already
  scans; no second skill tree.

## Evidence

- Exact base: `develop@2368ed62937abfabb159c23aa52b81dde58b3dbe`
- Live Grok `config.toml` MCP tables match Codex `mcp_servers.*`
- Signed binary: `Developer ID Application: X.AI Corporation (5Y6N3AJ54S)`
- Open PRs #3 and #4 remain independent and must not be closed for this delta

## References

Homebrew. (2026a). *grok: DRY and RAD for regular expressions*. Homebrew Core.
https://formulae.brew.sh/formula/grok

Homebrew. (2026b). *grok-build: Extensible coding agent for the terminal*.
Homebrew Cask. https://formulae.brew.sh/cask/grok-build

xAI. (2026a). *MCP servers*. Grok Build user guide.

xAI. (2026b). *Project rules (AGENTS.md)*. Grok Build user guide.

xAI. (2026c). *Hooks*. Grok Build user guide.

Anthropic. (2025). *Model Context Protocol specification*.
https://modelcontextprotocol.io
