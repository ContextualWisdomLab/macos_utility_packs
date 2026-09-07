# Product and technical gap baseline

Living baseline derived from protected `develop`, open PRs, ADRs, and
operator-visible doctor evidence. Update this file when a PR lands or a
gap is repaired. Do not treat a GitHub “closed” label as completion.

## Goal and loop

- **Goal:** a Mac that already has Codex/Claude-quality MCP, instructions,
  hooks, plugins, and doctor evidence also has that contract for Grok Build,
  without inventing a second catalog.
- **Loop:** review open PRs → repair findings on the owner stack → re-run
  checks → merge only when required gates are green → start the next gap.
  Review wait is not a blocker for encoding a verified successor delta.
- **KPI (self-set, 2026-09-07):** `grok_surface_coverage` 6/6 and
  `scripts/test` GREEN. Surfaces: agent-targets `grok-cli`, TOML MCP merge,
  `~/.grok/rules/AGENTS.md`, native CodeGraph hook, Ponytail
  `hooks/hooks.json`, doctor REQ-22 plus REQ-08/REQ-10 Grok evidence.

## Exact authority

| Item | Value |
| --- | --- |
| Protected base | `develop@2368ed62937abfabb159c23aa52b81dde58b3dbe` |
| This encoding branch | `feature/grok-native-client` |
| ADR | [ADR-0002](adr/ADR-0002-grok-native-client.md) Proposed |
| Product version | `0.1.0` development; not a release tag |

## Open PRs (do not simple-close)

| PR | Intent | Head | Mergeable | Finding |
| --- | --- | --- | --- | --- |
| [#3](https://github.com/ContextualWisdomLab/macos_utility_packs/pull/3) feat(skills) deny list | Security control for shared skills | `d74f327b25e6ed56f0d41dda0db616891be4ef8c` | blocked | Source is a repair-complete security delta. Required Security Scan fails at Dependency Review HTTP 403 owned by `ContextualWisdomLab/.github#810`. Keep open; do not merge through admin bypass. |
| [#4](https://github.com/ContextualWisdomLab/macos_utility_packs/pull/4) docs public surface | Pages-ready docs home, Apache-2.0 grant, DeepWiki badge | `7477c5808827361f8e839f1cc1600b5416e31145` | blocked | Same central Dependency Review gate. Independent of Grok encoding. Keep open. |

Local checkout of `feat/skill-blacklist` at `8348e4f` was behind origin
when this baseline was written; do not restack Grok work onto that stale
branch.

## Current gaps

1. **Grok native client (this change).** Closed in source on
   `feature/grok-native-client` once tests are green and the PR is merged
   to `develop`. Until merge, doctor on unmodified `develop` still omits
   Grok.
2. **Dependency Review 403.** Owner is `.github`, not this repository.
   Sibling OSV/Trivy/Scorecard GREEN does not substitute.
3. **CodeGraph installer has no Grok target.** Catalog TOML supplies the
   MCP server. Do not invent `--target=grok`.
4. **Ponytail plugin update may drop `hooks/hooks.json`.** Extensions
   recreate the relative symlink; a later `grok plugin update` without a
   bootstrap rerun is an operator gap.
5. **No repository-local hosted shell suite on PR heads.** Claims of test
   GREEN are local `scripts/test` plus this baseline, not a substitute for
   org CI.

## UML — Grok client boundary

```mermaid
flowchart LR
    Catalog[config/mcp-servers.json]
    Shared[config/AGENTS.shared.md]
    Hook[config/hooks/codegraph-prompt.json]
    Catalog --> Merger[merge-codex-mcp.py]
    Merger --> CodexToml[~/.codex/config.toml]
    Merger --> GrokToml[~/.grok/config.toml]
    Shared --> CodexAgents[~/.codex/AGENTS.md]
    Shared --> GrokRules[~/.grok/rules/AGENTS.md]
    Hook --> GrokHook[~/.grok/hooks/codegraph.json]
    Ponytail[DietrichGebert/ponytail] --> GrokPlugin[~/.grok/installed-plugins/ponytail-*]
    GrokPlugin --> HooksJson[hooks/hooks.json symlink]
```

## Actions

1. Land Grok encoding through normal protected review after local
   `scripts/test` GREEN.
2. Leave #3 and #4 open until `.github` Dependency Review is actually
   GREEN on those exact heads.
3. After Grok merge, restack #3/#4 only if they conflict; they currently
   do not own Grok adapter files.

## Citations

Homebrew. (2026). *grok-build cask*. https://formulae.brew.sh/cask/grok-build

xAI. (2026). *Grok Build user guide: configuration, MCP, hooks, plugins, project rules*.
