# ADR-0001: Keep the bootstrap local and fail closed on runtime evidence

- Status: Accepted
- Date: 2026-08-13

## Context

The project configures a developer Mac, merges agent-client configuration, and
diagnoses the resulting installation. It does not host an application or own a
cloud service. Colima can also retain an existing VM whose runtime differs from
the repository template.

## Decision

Keep the implementation as an idempotent local phase runner. Use Homebrew and
native launchd-backed `brew services` for installation, preserve unmanaged
configuration, and make `doctor` fail when the active Colima profile is not
`containerd`. Never delete or recreate an existing profile automatically.

## Consequences

- The repository stays small and has no service credentials or database state.
- `doctor` can expose a real runtime mismatch instead of trusting a template.
- A user must choose and perform any profile migration after considering backup
  and data loss; the installer will not make that irreversible choice.
- Future cloud or application code needs a new ADR and a separately owned
  deployment boundary.
