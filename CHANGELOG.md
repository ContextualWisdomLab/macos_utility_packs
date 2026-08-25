# Changelog

## [Unreleased] - 2026-08-13

- Added Claude Desktop, Codex CLI/cask, ChatGPT Desktop, and Visual Studio Code.
- Added conflict filtering for `mcp`, `claude`, `codex`, `grok`, and `build` skills.
- Added a JSON skill deny list (`config/skill-blacklist.json`) enforced by skills
  sync so known malicious or broken shared skills, including the homoglyph-named
  `re-d_data` prompt-injection payload, are skipped before installation;
  discovery listings may still surface blocked names. Matching uses full
  Unicode case folding so homoglyph spellings cannot bypass the block.
- Added a JSON skill deny list (`config/skill-blacklist.json`) enforced by skills
  sync so known malicious or broken shared skills, including the homoglyph-named
  `re-d_data` prompt-injection payload, are skipped during discovery.
- Registered Colima with `brew services start colima` and verified its active
  runtime before reporting the container requirement as passing; installation
  now fails closed when the active profile is Docker or unavailable.
- Added JSON doctor evidence, standards scope, and project architecture notes.
- Added deterministic Python API/error-path tests with 100% executable-line
  coverage and an opt-in live Homebrew/Colima runtime test.
- Tightened review paths: doctor requires a started Colima service, wildcard
  child failures stay failures, and blank public docstrings are rejected.
- Documented the central OpenCode/Noema PR loop and its 15/30-minute sweep
  cadence instead of adding a duplicate local scheduler.

## Versioning

The current development version is recorded in [`VERSION`](VERSION) and follows
semantic-version-style `MAJOR.MINOR.PATCH` values. A release tag and package
artifact are required before calling a version released.
