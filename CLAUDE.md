# Yaht

SwiftUI + SwiftData habit tracker for iOS. Pushes to `main` ship to TestFlight
through Xcode Cloud (`.github/workflows/testflight.yml`), so every merge to
`main` is a release.

## Versioning

Yaht follows [Semantic Versioning](https://semver.org): `MAJOR.MINOR.PATCH`.

- **Version** (`MARKETING_VERSION` in `Yaht.xcodeproj/project.pbxproj`) is
  set by hand. Every PR that changes the app (anything under `Yaht/`,
  `Yaht.xcodeproj/` or `Configuration/`) bumps it in the same PR:
  - **PATCH** for bug fixes and small polish (`0.2.0` → `0.2.1`).
  - **MINOR** for new features or visible behaviour changes, resetting PATCH
    (`0.2.1` → `0.3.0`).
  - **MAJOR** for breaking changes, such as dropping data or an iOS version.
    It stays `0` until the first App Store release, which is `1.0.0`.
- Change the version in **all four** build configurations (Yaht and YahtTests,
  Debug and Release) so they never drift apart.
- Several PRs merging the same day may share one bump; take the highest level
  among them. CI-, docs- and script-only PRs don't bump.
- **Build number** (`CURRENT_PROJECT_VERSION`) is assigned by Xcode Cloud on
  every archive. Leave it at `1` in the project; never set it by hand.
- Name the version in the PR title or body (for example "Bumps to 0.3.0").
