# Validate Yaht against the iOS 27 SDK and generated app metadata

Priority: P1. Required before claiming iOS 27 compatibility.

## Confirmed requirements

Apple’s iOS 27 release notes confirm SDK 27 is bundled with Xcode 27;
`@State` becomes a macro with initialization and source-compatibility caveats
(105893279); apps built with SDK 27 need a launch-screen Info.plist key
(168247372) and the scene lifecycle (141837548). Several control environment
values reset at sheet/popover boundaries (167448274).

Source: https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes
Toolchain: https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes

Yaht already uses SwiftUI App/WindowGroup, scene-manifest generation, and
launch-screen generation in both configurations. Explicitly initialized state
has explicit types and no competing declaration default. Those source audits
do not prove SDK compilation or built metadata validity.

## Acceptance criteria

- Add a reusable macOS validation command using actual Xcode 27+ and SDK 27+.
  Require a caller-selected simulator destination rather than guessed hardware
  or runner image names.
- Build Debug/Release and inspect generated Info.plist for one of
  UILaunchStoryboardName, UILaunchStoryboards, UILaunchScreen, UILaunchScreens,
  plus scene configuration.
- Execute real tests with a fresh result bundle, preserve command failures,
  confirm nonzero test counts, and record outcomes.
- Validate editor draft lifetime under the State macro, sheet controls,
  existing-store upgrades, sync, reminders, and accessibility on iOS 27.
- Retain the iOS 26 minimum and report baseline/new SDK results separately.
- Update CI only after the runner image and destinations are confirmed.

Implementation branch: `test/ios27-sdk-readiness`.
This Linux environment cannot execute Apple-platform checks.

Remote issue: https://github.com/4499io/yaht/issues/4
