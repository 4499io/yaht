# iOS 27 migration investigation

## Status

The app retains iOS 26.0 minimum support. Official Apple research now verifies
SDK 27/Xcode 27 changes and iOS 27.1 adaptive layout APIs. See the
[verified research](research.md) for exact source links, availability, and
which changes affect this app. Network access was restored and the issues
below were filed successfully. Apple-platform builds/runtime remain unverified
because this environment runs Linux.

Confirmed requirements include new State macro semantics, launch-screen keys,
scene lifecycle, and changed sheet/popover control environment propagation.
Yaht already configures generated launch screens and uses SwiftUI App/WindowGroup;
the remaining work includes checking the generated app and compiling the State
initializers, rather than blindly changing otherwise valid settings.

New reserved-region APIs are available from **iOS 27.1**, not 27.0. The adaptive
layout branch preserves baseline builds behind `YAHT_IOS27_1_SDK`; the SDK
validation runner enables this condition only when it detects SDK 27.1+.
Use runtime availability checks as well. Compiler version alone does not
identify the SDK.

Do not raise the minimum deployment target solely to support a newer OS.
Do not change the SwiftData schema without an explicit existing-store migration
plan. The current CI runner and simulator still target Xcode/iOS 26; a new CI
image must be verified before replacing it.

## Code-confirmed preparation

| Issue | Priority | Work | Branch | Status |
| --- | --- | --- | --- | --- |
| [#1](https://github.com/4499io/yaht/issues/1) | P1 | Preserve database on startup failure | `fix/preserve-persistent-store` | `372b200`, `57860c8`, `738f33a`; five tests added, Apple validation pending |
| [#2](https://github.com/4499io/yaht/issues/2) | P2 | Label and enlarge editor controls | `fix/habit-color-accessibility` | `6bc58ee`, `0e9c3ec`; Apple validation pending |
| [#3](https://github.com/4499io/yaht/issues/3) | P2 | Reconcile/serialize device reminders | `fix/reconcile-reminders` | `b5a86c9`, `98a109a`; 13 tests added, Apple validation pending |
| [#4](https://github.com/4499io/yaht/issues/4) | P1 | Validate SDK 27 builds and generated metadata | `test/ios27-sdk-readiness` | `0a043a0`, `668ff0d`, `c3be522`; reproducible Linux validator tests pass, actual Xcode validation pending |
| [#5](https://github.com/4499io/yaht/issues/5) | P1 | Avoid active hardware divisions on 27.1 | `feat/ios27-reserved-region-layout` | `dbda231`, `043a2d4`; 11 geometry tests added, Apple validation pending |

Issues #1–3 address existing defects. Issues #4–5 cover confirmed new-SDK
requirements and adaptive API adoption. Worktrees are under `/workspace/yaht-worktrees/`;
the original checkout remains on its existing branch.

Upstream branch publishing remains blocked: the current GitHub identity has
read/issue access but no repository push permission. Fork creation was also
attempted and rejected with `Resource not accessible by integration` (HTTP
403). All implementation commits remain local; restore repository write access
or supported fork permission before publishing. Apple research and issue API
access now work; the former network blocker is resolved.

An integration worktree at `/workspace/yaht-worktrees/ios27-integration`, branch
`integration/ios27-upgrade`, combines the independent fixes for Apple-platform
validation. The original checkout remains unchanged. No remote PR, merge, or
deployment has been created.

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

## Remote status

All five issues are filed in `4499io/yaht`. Local issue body copies are kept in
`issues/` for review. Issues stay open until their acceptance criteria and
Apple-platform validation pass.

The current GitHub account has `pull: true`, `push: false`. Creating issues
works; publishing implementation branches is still blocked by repository write
permission. No branches were force-pushed, merged, or deployed.

## Prepared integration and checks

`integration/ios27-upgrade` combines all five implementation branches and the
research record in `/workspace/yaht-worktrees/ios27-integration`. No upstream
changes were merged. New Apple-platform regressions comprise five persistence,
thirteen notification reconciliation, and eleven free-rectangle cases; all
29 are unrun here. The reproducible Python validator suite passed three test
methods covering thirteen simulated command scenarios. Python syntax, project
XML and whitespace checks passed on the combined worktree. Palette tokens and
ordering remain unchanged. These checks do not establish app/SDK compatibility.

Read-only reviews corrected async notification removal/identifier reuse,
cancelled queued work, negative geometry handling, and recovery-screen adaptive
layout coverage. A notification removal timeout defers further scheduling until
the next foreground/data reconciliation event; validate this on a real device.

On macOS, follow [the SDK validation guide](../IOS27_VALIDATION.md) and
[adaptive layout guide](adaptive-layout.md). Use SDK 27.1+ with the explicit
compilation condition and runtime 27.1+ to exercise hardware-division behavior;
a test running on runtime 27.0 only checks the fallback. Run iOS 26 compatibility
checks separately, including existing data and notification permissions.
