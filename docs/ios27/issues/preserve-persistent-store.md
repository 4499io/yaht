# Preserve the existing store when CloudKit initialization fails

Priority: P1. Existing defect relevant to OS upgrades; no iOS 27-specific
change has been verified.

## Problem

`Yaht/YahtApp.swift` catches every persistent CloudKit container construction
error, renames the SQLite database and sidecars, and retries with a fresh
store before trying local persistence. A transient CloudKit, entitlement, or
SDK initialization error can therefore make the user's existing habits
disappear from the active store. The purported local configuration omits
`cloudKitDatabase: .none`. If all persistent attempts fail, the app silently
allows writes to an in-memory store that disappear on the next launch.

## Acceptance criteria

- Attempt CloudKit, then explicit local-only persistence using the same URL.
- Do not move/delete/reset the original SQLite database or sidecars merely
  because initialization fails.
- If both persistent attempts fail, surface a recovery screen with retry;
  do not offer a writable in-memory app session.
- Keep the intentional in-memory unit-test container separate.
- Add regression tests covering success, fallback order/configuration,
  preservation of existing files, and both attempts failing.
- Update recovery documentation without changing the model schema.
- Run tests on macOS and manually verify an existing populated store survives
  CloudKit initialization failure and an OS upgrade.

Implementation branch: `fix/preserve-persistent-store`.
Remote issue: https://github.com/4499io/yaht/issues/1

## Implementation progress

Implementation prepared locally on `fix/preserve-persistent-store` (latest `738f33a`): preserved original store, explicit local fallback, blocking Retry UI, five added regression cases including real local SQLite roundtrip. Swift tests and CloudKit-backed device behavior remain unrun. Recovery presentation also uses the adaptive layout constraint.

Branches remain local: upstream push permission is absent, and GitHub integration denied fork creation. Issue remains open pending acceptance checks.
