# Verify official iOS 27 changes and run the app compatibility matrix

Priority: P1. Required before claiming iOS 27 compatibility.

## Blockers

Requests to Apple's documentation and website fail at the HTTPS proxy with
CONNECT 403. This does not establish whether iOS 27 notes are published.
This environment runs Linux and has no Xcode or iOS simulator.

## Acceptance criteria

- Restore access to `developer.apple.com` and `www.apple.com`, read official
  release notes and Xcode notes, and record exact sources and SDK versions.
- Map confirmed SwiftUI, SwiftData, CloudKit, UserNotifications, accessibility,
  and SDK-linked behavior changes to affected app code.
- File individual actionable issues for verified changes, including source
  links and before/after behavior. Keep assumptions explicitly unverified.
- Establish the iOS 26 baseline and run build, real unit tests, application
  smoke checks, populated-store upgrade, sync, reminders, and accessibility
  checks on iOS 27. Record actual test counts and outcomes.
- Preserve the iOS 26 minimum target unless a verified requirement or product
  decision warrants changing it.
- Update CI only after the required runner/SDK/destination are confirmed.

Sources and detailed matrix: `docs/ios27/README.md`.
Implementation branch: `chore/ios27-migration-plan`.
Remote issue: not filed; API access is blocked.
