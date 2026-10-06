# iOS 27 SDK validation

Apple's [iOS and iPadOS 27 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes) describe the launch-screen Info.plist requirement (168247372), scene lifecycle requirement (141837548), and `@State` macro source compatibility caveats (105893279). [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes) describe the bundled iOS 27 SDK. Recheck these living release notes against the installed Xcode build when validating.

Yaht already generates `UILaunchScreen` and `UIApplicationSceneManifest` for Debug and Release, and its SwiftUI `App` uses `WindowGroup`. Validate the emitted app rather than assuming build settings prove compliance. The deployment target remains iOS 26; building with SDK 27 does not require dropping iOS 26 support.

## Run on macOS

Install/select a full Xcode 27 or later, Python 3, and an iOS 27 or later simulator runtime. Select Xcode with `DEVELOPER_DIR` if multiple versions are installed. Find an available simulator with `xcrun simctl list devices available` or `xcodebuild -project Yaht.xcodeproj -scheme Yaht -showdestinations`. Supply its UDID explicitly:

```sh
python3 scripts/validate_ios27.py 'platform=iOS Simulator,id=<installed-simulator-UDID>'
```

The script verifies macOS, Xcode major version, simulator SDK major version and the selected simulator's iOS runtime major version. It runs the existing `YahtTests` target in Debug, builds Release, and checks both emitted app plists for a launch-screen configuration (`UILaunchScreen`, `UILaunchScreens`, `UILaunchStoryboardName` or `UILaunchStoryboards`) and a scene manifest. Supply an available simulator's **UDID**, not an ambiguous device name. Run the existing CI test command separately against an iOS 26 simulator for backward compatibility if that runtime is available; this SDK validation script intentionally requires an iOS 27+ runtime.

Every invocation creates a fresh directory under the system temporary directory, prints its location, and retains separate DerivedData directories, logs, `Tests.xcresult` and `test-summary.json` for review. Build output goes to the printed log files. A tool failure preserves its exit status. `xcresulttool get test-results summary` must report integer `totalTestCount`, `passedTests` and `failedTests`, at least one executed passing test, and zero failures. An unfamiliar summary schema fails validation and preserves the raw JSON for diagnosis; consult the installed tool's help before adapting the parser. No package or macro verification bypasses are enabled.

`Configuration/SDKConditions.xcconfig` adds `YAHT_IOS27_1_SDK` to the app's active compilation conditions whenever the build uses SDK 27.1 or later (matched on the SDK name, e.g. `iphoneos27.1`), so Xcode, Xcode Cloud and command-line builds need no manual setting. SDK 27.0 and 26 leave it unset. Swift compiler version alone does not establish SDK 27.1 API availability; runtime availability checks still protect earlier OS versions. The script reads `xcodebuild -showBuildSettings` for both configurations and fails unless the condition is set exactly when the selected SDK is 27.1 or later; the CI iOS 26 job checks it is unset there.

Simulator builds disable signing; this check does not validate signed device entitlements, iCloud sync or App Store submission. It performs no deployment and requires no credentials. The current GitLab runner remains on Xcode 26 until an actual Xcode 27 runner is available; no speculative runner image is configured here.

## State source audit and runtime regression matrix

The audited `@State` declarations use private named properties with explicit types or initial values. No definite source compatibility defect was identified. Two initialization sites explicitly construct state storage: `HabitEditView.init` initializes `_viewModel`; `YahtApp.init` initializes app startup state (the baseline `_container`/`_store`, or `_startup` with the persistence recovery changes). Compile the declarations present in the checked-out branch under the Xcode 27 compiler and investigate actual diagnostics before changing their initialization semantics. Existing Swift Testing suites cover habit logic, storage, notification trigger construction and color blending; they do not exercise SwiftUI state lifetime or presentation.

Complete this matrix on iOS 27 and, where available, iOS 26. Record Xcode build, simulator/runtime version, device, results and relevant screenshots. Passing the script alone does not establish these behaviors.

| Area / state | Regression check |
| --- | --- |
| App container / startup state | Cold launch with existing habits; verify records remain after background/foreground and relaunch. Exercise any recovery state present in the branch. Confirm test startup uses the in-memory container and existing suites execute. |
| List `showingEditor` | Open Add Habit from empty and populated lists; cancel, reopen, then save. The sheet must dismiss correctly and the list must update. |
| Detail `showingEditor` | Open a habit, edit, cancel and reopen; save an edit and verify detail and list update. |
| Editor `_viewModel` | Type a name/emoji; change color, habit kind, weekday schedule and reminders. Trigger view refresh and ensure unsaved edits remain. Cancel must preserve the original habit; save must persist the edited values. |
| Sheet and popover controls | Check native sheet dismissal controls and popover presentation after rebuilding with SDK 27 (release note 167448274). Verify placement, keyboard interaction, VoiceOver and that Cancel/Save remain reachable. No source override for native presentation controls is currently applied. |
| Scenes and launch screen | Cold launch Debug and Release; confirm a launch screen and usable initial scene. Background/foreground and reconnect the scene without losing navigation or data. |
| SDK/runtime coexistence | Repeat critical launch, edit and persistence flows on iOS 26 when supported by the host Xcode installation. |

This validation is prepared for macOS execution. Linux script/stub checks provide no evidence that Yaht builds or runs with Xcode 27.

## Reproduce validator tests on Linux or macOS

```sh
python3 -B -m unittest discover -s scripts/tests -p 'test_validate_ios27.py' -v
```

These tests create temporary fake `xcodebuild` and `xcrun` executables. They cover Linux rejection, minimum toolchain/runtime versions, SDK 27.1 flag gating in both configurations, launch-screen variants, missing plist requirements, preserved tool failure statuses, zero/all-skipped/failed tests, and unknown xcresult schemas. They exercise the validator's command handling and leave the repository unchanged; they do not execute app tests or simulate actual SDK compatibility.
