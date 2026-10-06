# iOS 27 migration investigation

## Status

The app currently targets iOS 26.0 and its CI selects `macos-26-xcode-26`
and an iPhone 17 Pro simulator. No iOS 27 API, behavior change, SDK version,
or release requirement has been verified in this investigation.

Official-source requests fail at the environment's HTTPS proxy with CONNECT
403, before reaching Apple. This is a network access failure, not evidence
that iOS 27 documentation exists or does not exist. GitHub API access is
also blocked, so the files in `issues/` are **local issue drafts**, not filed
GitHub issues. Do not assign remote issue numbers until creation succeeds.

The environment configuration draft adds `developer.apple.com`,
`www.apple.com`, and `api.github.com` to custom allowed domains. Applying
that configuration and rechecking connectivity are still required.

## Research sources to verify

- Release notes index: https://developer.apple.com/documentation/ios-ipados-release-notes
- Candidate iOS 27 release notes (unverified): https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes
- Apple developer releases: https://developer.apple.com/news/releases/
- Public iOS overview: https://www.apple.com/ios/

Read official release notes and linked SwiftUI, SwiftData, CloudKit,
UserNotifications, accessibility, and Xcode notes. Record the SDK/build,
source URL, exact relevant change, affected code, and required validation
for each finding. Distinguish SDK-linked behavior changes from changes that
also affect the existing binary on the new OS. Do not infer requirements
from the OS version number.

Do not raise the minimum deployment target solely to support a newer OS.
Keep iOS 26 compatibility unless a verified requirement or product decision
calls for dropping it. Do not change the SwiftData schema or persisted values
without an explicit migration plan and existing-store tests.

## Code-confirmed preparation

| Local draft | Priority | Finding | Branch | Status |
| --- | --- | --- | --- | --- |
| [Preserve persistence](issues/preserve-persistent-store.md) | P1 | Any CloudKit startup error moves the existing SQLite store aside; local fallback is not explicitly local; final fallback silently accepts volatile writes | `fix/preserve-persistent-store` | Committed as `372b200`; Apple-platform validation pending |
| [Editor accessibility](issues/editor-accessibility.md) | P2 | Color-only buttons lack spoken names and editor controls have small targets | `fix/habit-color-accessibility` | Committed as `6bc58ee` and `0e9c3ec`; Apple-platform validation pending |
| [Notification reconciliation](issues/notification-reconciliation.md) | P2 | Bulk reminder reconciliation has no callers; scheduling operations can interleave at awaits | Not started | Needs focused implementation and regression tests |
| [Verify iOS 27 compatibility](issues/verify-ios27-compatibility.md) | P1 | Official release research and Apple-platform validation remain unavailable | `chore/ios27-migration-plan` | Blocked on access and macOS tooling |

These findings are existing defects or validation gaps, not claims about
new iOS 27 requirements. Worktrees are under `/workspace/yaht-worktrees/`;
the original checkout remains on its existing branch.

## Required validation matrix

Use a macOS machine with the appropriate Apple SDKs. This Linux environment
cannot compile SwiftUI/SwiftData, run the app, or execute its Swift Testing
suites. No simulator or device test has run here.

1. Establish the existing iOS 26 baseline with the repository CI test command.
2. After verifying available SDKs and supported destinations, compile and run
   the same scheme with the iOS 27 SDK and simulator. Record actual Xcode/SDK
   versions; do not substitute guessed runner image or simulator names.
3. Run all existing unit tests and new persistence regression tests. Preserve
   `xcodebuild`'s exit status if piping output and confirm nonzero test count
   in the fresh result bundle.
4. Test an upgrade using a populated existing on-disk store: habit names,
   logs, counts, schedules, reminders, and relationships must survive.
5. Test CloudKit unavailable at launch, subsequent recovery, and sync between
   devices. If both local and cloud initialization fail, preserve the original
   files and show recovery UI instead of accepting writes that disappear.
6. Test notification permission denied/granted, foreground presentation,
   imported reminders, edited/deleted reminders, and request-budget limits.
7. Test VoiceOver, largest Dynamic Type, Reduce Motion/Transparency, contrast,
   and narrow iPhone layouts. Exercise create/edit/complete/archive habits.

Build and simulator tests may disable signing as in CI. CloudKit behavior and
notification delivery need an appropriately provisioned device/account.
App Store deployment is a separate action and is not authorized by this plan.

## Filing drafts after access is restored

First check existing issues to avoid duplicates:

```sh
gh issue list --repo 4499io/yaht --state all --limit 100
```

From this checkout, create each remaining issue with its title from the draft
and `--body-file docs/ios27/issues/<file>.md`. Record the returned URL in this
table and link the corresponding branch. Creating drafts locally does not
prove remote filing or API permissions. Do not close implementation issues
until Apple-platform checks pass.
