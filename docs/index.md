# macOS Utility Packs

`macos_utility_packs` is an idempotent macOS bootstrap for AI developer workstations. It configures a reviewed toolchain, preserves unmanaged local settings, keeps credentials out of the repository, and provides read-only post-install diagnostics.

## Start here

1. Read the [repository overview](../README.md).
2. Preview changes with `./bootstrap --dry-run`.
3. Run `./bootstrap` for the full workstation setup or choose a bounded stage.
4. Complete interactive credentials with `./bootstrap auth`.
5. Verify the workstation with `./bootstrap doctor` or machine-readable `./bootstrap doctor --json`.

For the full operator flow, use the [Korean manual](korean-manual.md).

## Product and architecture

The bootstrap favors repeatable package management, preserves user-managed configuration outside its owned surface, and uses Colima with containerd/nerdctl instead of silently changing container runtimes. Kubernetes is opt-in through a separate profile. Secrets and login material remain outside version control.

- [Repository README](../README.md) — product scope, commands, diagnostics, and tests.
- [Korean manual](korean-manual.md) — detailed installation and operation guidance.
- [Standards and security evidence](standards.md) — security, compliance, and non-certification boundaries.
- [Changelog](../CHANGELOG.md) — development changes and release/versioning rules.

## Release status

The repository currently documents development version `0.1.0`. The changelog requires a release tag and package artifact before a version is described as released, so this documentation does not promote an unreleased source version to a published release.

## Contributing and verification

Before changing workstation behavior, run the deterministic test suite:

```bash
scripts/test
```

The opt-in live check reads the real Homebrew, Colima, and nerdctl state without installing packages or deleting profiles:

```bash
RUN_LIVE_TESTS=1 bash tests/live_test.sh
```

Security-sensitive changes should preserve fail-closed behavior, avoid writing credentials, and keep public documentation aligned with the exact shipped behavior.
