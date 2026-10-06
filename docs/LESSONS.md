# Yaht — Lessons Learned from 99issues

Distilled from `/home/claude/git/99issues/xcode` (400+ iterated issues). Yaht reuses the
**infra, design conventions, and CI/CD** — not the sync engine, GitLab API, or multi-account code.

Legend: **COPY** = take the file nearly verbatim · **PATTERN** = copy the idea, rewrite for Yaht ·
**SKIP** = do not bring over · **GOTCHA** = mistake already paid for, don't repeat.

---

## 0. Hard environment facts (unchanged from 99issues)

- **No Xcode/macOS on this Linux VPS.** No `xcodebuild`, `xcrun`, `swift build`, simulators.
  Tests run in GitLab CI on MR pushes; archives run in **Xcode Cloud** when `project.pbxproj`
  changes on `main`. Same model as 99issues — reuse it wholesale.
- **Never hand-edit `project.pbxproj`** for adding files — the project uses Xcode automatic file
  discovery. New `.swift` files just appear. (But: creating the *initial* `.xcodeproj` needs a Mac —
  see PLAN.md open question #1.)
- **iOS 26 / Xcode 26 SDK.** 99issues targets `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, runners
  `macos-26-xcode-26`, uses `.buttonStyle(.glass)` and native Liquid Glass. Yaht should match.
- **Feature branches only.** Never commit to `main` directly (Xcode Cloud watches `main`).
  Arm auto-merge right after MR create; re-arm after every push.

---

## 1. CI/CD — the "never relive it" bundle

**COPY these files, re-point the IDs. This is the crown jewel.**

| File (in 99issues) | What it does | Change for Yaht |
|---|---|---|
| `.gitlab-ci.yml` | 2 jobs: `test` (MR-only, `rules:changes`, sim `iPhone 17 Pro`, signing disabled) + `deploy:testflight` (main, manual → `scripts/asc trigger`) | Replace every `99issues*` glob/scheme/target, sim device, `rules:changes` paths |
| `scripts/asc` (14 KB bash) | ASC + Xcode Cloud CLI. JWT via inline PyJWT/ES256. Cmds: `builds`, `testflight`, `distribute`, `submit`, `whats-new`, `trigger`, … | **Lines 22-31: `KEY_ID`, `ISSUER_ID`, `APP_ID`, `WORKFLOW_ID`, `BETA_GROUP_ID`, `EXTERNAL_GROUP_ID`** — all Yaht-specific |
| `ci_scripts/ci_post_xcodebuild.sh` | Xcode Cloud post-archive hook; uploads dSYMs to Sentry. Hard-fails archive if Sentry env missing (never ship unsymbolicated) | Keep filename (Xcode Cloud auto-runs `ci_scripts/*`); set Sentry env in workflow |
| `scripts/fetch_testflight_feedback.py` | Pulls TestFlight tester feedback via ASC API | New App ID / key |
| `.gitignore` | Well-annotated; blocks `*.p8 *.p12 *.mobileprovision Local.xcconfig Secrets.swift testing-creds.txt appstoreconnect.txt` | Copy as-is |

**Signing:** no `exportOptions.plist`, no Fastlane, no committed profiles — signing/upload fully
delegated to **Xcode Cloud**. CI test job sets `CODE_SIGNING_ALLOWED=NO`. Keep this — it's clean.

**Secrets required (never commit):**
- GitLab CI/CD vars (Protected): `ASC_AUTH_KEY` (File type → path to `.p8`), `ASC_KEY_ID`, `ASC_ISSUER_ID`
- Xcode Cloud workflow env: `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, `SENTRY_PROJECT`

**GOTCHA — 99issues has live creds committed on disk** (`.mcp.json` with a real `glpat-…`,
`AuthKey_*.p8`, `appstoreconnect.txt`). Do **NOT** copy those files. Reference only.

**Release flow (from `docs/xcode-cloud.md`):** bump `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`
in pbxproj → push `main` → Xcode Cloud archives+uploads → `asc testflight` (wait `VALID`) →
`asc distribute <build>` → `asc submit <build> "notes"` → review ~24h.
- **GOTCHA:** Xcode Cloud overrides `CURRENT_PROJECT_VERSION` with its own auto-increment — the
  pbxproj value is human-reference only. TestFlight build number will differ.
- **GOTCHA:** SwiftData migrations are forward-only. Installing an older build over a newer store
  bricks it. Ship a `VersionedSchema` + `SchemaMigrationPlan` **from day one** (§3).

---

## 2. Liquid Glass — feels-like-Apple rules

There is **no centralized theme module** in 99issues — the "design system" is *conventions + inline
system materials + a runtime tint*. Yaht will need a real theme layer (always-dark Cyberdream), but
the rules below are the hard-won part.

**Material vocabulary (copy verbatim):**
- Cards: `.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))`
- Pills/badges: `.background(.ultraThinMaterial, in: Capsule())`
- Buttons: `.buttonStyle(.glass)` (iOS 26 native)
- Thickness hierarchy: `.ultraThinMaterial` (pills) → `.regularMaterial` (cards).

**GOTCHAS (each is a documented mistake, `docs/2026-03-07_DESIGN-GUIDELINES.md` + `refactor-spec.md`):**
- **Never override system backgrounds.** No `.toolbarBackground()`, no `.scrollContentBackground(.hidden)`,
  no manual `.background(Color(...))` on containers. Let content peek through glass. (They *removed*
  these from 6 views after the fact.)
- **Toolbars:** use `ToolbarItemGroup` + `ToolbarSpacer(.fixed)` — never `HStack` inside `ToolbarItem`.
- **Modal save buttons:** `.confirmationAction` placement. Glass belongs to the **navigation layer only**,
  never on content-layer elements.
- **GOTCHA (crash):** never mutate `@Observable` state while a Menu or Sheet is dismissing. Use
  `@State` + `.onChange` for Menus; no deferred mutations in Sheet callbacks.

**Dark mode — KEY DIVERGENCE for Yaht.** 99issues relied on system materials for *automatic* light/dark
adaptation and explicitly removed all `@Environment(\.colorScheme)` overrides. **Yaht is always-dark
Cyberdream.** So:
- Lock it at the system level: `UIUserInterfaceStyle = Dark` in Info.plist (so system chrome/keyboard
  are dark too) — do **not** just slap `.preferredColorScheme(.dark)` on the root view.
- Still use system materials (they render correctly in dark) — but layer the Cyberdream accent palette
  on top for tints/habit colors, not for backgrounds.
- **Tension to resolve in design phase:** Cyberdream is neon-on-black; spec says "never overwhelming,
  no flashing bright screen in dim environments." → muted/desaturated accents, deep near-black bg,
  restrained glow. Flagged in PLAN.md.

**Reusable color util — COPY:** `99issues/Utilities/Color+Hex.swift` (`Color(hex:)` 3/6/8-digit + `toHex()`).
The `AccountColor` swatch enum → rename to a Yaht habit-color palette (Cyberdream hues).

**Reusable generic components (PATTERN, not GitLab-coupled), from `99issues/Views/Components/`:**
`FlowLayout` (wrapping tags), `LabelPill`/`LabelPillsView`, `DetailRow`, `TitleCard`, `DescriptionCard`,
`CollapsibleContentView`, `MultiSelectPickerList`, `SlideshowView` (onboarding), `FullScreenTextEditorView`,
`View+PhoneWidthConstrained` (`.phoneWidthConstrained()` — iPhone-only clamp, useful even though Yaht is
iPhone-only). Copy as starting points; restyle to Cyberdream.

---

## 3. Scaffolding — copy the skeleton

**Folder layout (mirror it):**
```
Yaht/            App/ Models/ Views/{Components,Screens} ViewModels/
                 Services/{Implementations,Protocols} Utilities/ Assets.xcassets/
                 Info.plist  Yaht.entitlements
YahtTests/       Helpers/ Models/ Services/ ViewModels/ Views/ Fixtures/
Configuration/   Debug.xcconfig  Release.xcconfig
ci_scripts/      ci_post_xcodebuild.sh
scripts/         asc  fetch_testflight_feedback.py
docs/  (maestro/  observability/  — optional)
```

**App entry (`App/*.swift`) — PATTERN, high value:**
- Build `ModelContainer` in a `@State` closure with an **explicit store URL** in Application Support,
  a `migrationPlan`, and an `excludeFromBackup()` helper marking `.sqlite`/`-shm`/`-wal` excluded.
- **Preserve the existing store on startup failure:** a CloudKit or SDK error does not establish
  corruption. Try an explicitly local (`cloudKitDatabase: .none`) container at the same URL.
  If both attempts fail, keep the database and sidecars in place and offer Retry; never silently
  replace the store or accept new entries in a volatile in-memory session.
- **`isRunningTests` guard:** checks `XCTestBundlePath`/`XCTestSessionIdentifier`; renders `Color.clear`
  and skips service startup under test — keeps unit tests from booting the whole app. COPY.
- Set `UNUserNotificationCenter.current().delegate` in `init()`.

**SwiftData — PATTERN:** `Models/AppSchema.swift` = `SchemaV1: VersionedSchema` (lists every `@Model`) +
`AppMigrationPlan: SchemaMigrationPlan`. **Do this from day one** (forward-only migrations).
For Yaht add CloudKit: `ModelConfiguration(..., cloudKitDatabase: .automatic)` + the iCloud/CloudKit
entitlement — SwiftData mirrors to CloudKit for free (this *replaces* the whole sync engine you dreaded).

**xcconfig secret injection — COPY the whole pattern (this is how Sentry/analytics stay optional):**
- `Debug.xcconfig` / `Release.xcconfig` each just `#include? "Local.xcconfig"` (gitignored).
- `Local.xcconfig` defines `SENTRY_DSN`, etc.
- Surface to runtime via **`$(VAR)` substitution in `Info.plist`** — NOT `INFOPLIST_KEY_` (breaks on
  values containing `@`, e.g. a Sentry DSN). GOTCHA already paid for.
- Services read `Bundle.main.infoDictionary?["SentryDSN"]` and **safe no-op when empty/placeholder**
  → fresh checkout builds & runs with zero secrets. COPY this contract.

**Entitlements/Info.plist:** App Group + `NSFileProtectionComplete` data-protection entitlement on all
targets; write temp files with `.completeFileProtection`. For Yaht add **iCloud/CloudKit** entitlement.
`UIUserInterfaceStyle = Dark` (see §2).

**Build-setting note:** the `PRODUCT_MODULE_NAME = _99issues` leading-underscore trick exists only because
the target starts with a digit. **"Yaht" starts with a letter → you don't need it.** Module = `Yaht`,
tests `@testable import Yaht`.

**Keychain — COPY (generic):** `99issues/Auth/KeychainService.swift` + `KeychainServiceProtocol`. Its
current caller is excluded multi-account code, but the wrapper itself is reusable. GOTCHA it encodes:
don't treat `errSecInteractionNotAllowed` (locked keychain) as "missing" — handle it distinctly.
(Yaht may not need Keychain at all in v1 — no tokens. Keep only if a secret appears.)

---

## 4. Notifications — GREENFIELD (biggest build effort)

**Blunt finding: 99issues has almost no local-notification infra.** Yaht's core feature (per-habit
reminders) is net-new. What exists to reuse:
- `NotificationDelegate` (`UNUserNotificationCenterDelegate`, returns `[.banner, .sound]` from
  `willPresent` for foreground display) — COPY the delegate shape.
- One-shot `requestAuthorization([.alert,.sound])` + `UNMutableNotificationContent` + immediate request
  — PATTERN for the permission prompt only.

**Build fresh for Yaht (no prior art — design carefully):**
- Per-habit `UNCalendarNotificationTrigger` with `DateComponents(weekday:hour:minute:)`,
  `repeats: true`. Fan out weekday vs weekend schedules into separate requests.
- Stable identifier scheme: `habit-<id>-<weekday>-<slot>` so edits/deletes can cancel precisely
  (`removePendingNotificationRequests(withIdentifiers:)`).
- Custom tones: bundle sound files, `UNNotificationSound(named:)`. iOS caps custom sounds at 30s / caf.
- Reschedule on habit create/edit/delete and on notification-permission change.
- iOS pending-notification limit is **64** — budget identifiers; don't naively schedule every
  occurrence far out.

---

## 5. Testing — reuse the mock pattern

- Test module mirrors source folders. `@testable import Yaht`.
- **Mock pattern (COPY the shape):** protocol per service (`Services/Protocols/`), hand-written mock
  `final class … : SomeProtocol, @unchecked Sendable` with (a) `…Called` spy flags + captured args,
  (b) `…Result`/`…Error` stubs, (c) methods default to `throw MockError.notConfigured`. No mocking
  framework. This is *why* services sit behind protocols — keep that structure.
- **All new functionality ships with tests** (services + view models, mocked deps). Tests run in CI only.
- UI testing in 99issues = Maestro flows (`maestro/*.yaml`, incl. `00_validate_identifiers.yaml`
  accessibility-id smoke test). Optional for Yaht; the numbering convention is the reusable bit.
- No snapshot-image library exists — don't expect one.

---

## 6. Conventions to import wholesale (`docs/conventions.md` + CLAUDE.md)

- SwiftUI only. `@Observable` view models (**not** `ObservableObject`). `async/await` everywhere.
- All types implicitly `@MainActor` (default isolation); `nonisolated` explicitly when needed. Swift 6.
- **File size ≤ ~400 lines**; split with `+Feature.swift` extensions. Views < 100 lines. One primary type/file.
- **No force-unwraps** outside tests/previews. `guard` for early returns.
- **Never `try?` for persistence/mutation** — `do/catch` + `CrashReportingService.capture(error)`.
  Only OK `try?` is read-only `modelContext.fetch()`.
- Accessibility IDs: `kebab-case`, `{context}-{element-type}`, on the **interactive element itself**.
- Date formatting: ISO 8601 via a shared `AppDateFormatters` — never inline `DateFormatter`.
- **Second occurrence = extract.** Batch fetch, not per-row. SwiftData indexes mandatory on predicate fields.
- Git identity per-repo; conventional commits (`feat:` `fix:` `test:` `docs:` `refactor:` `chore:`);
  include issue IID in branch + commit.

---

## 7. SKIP — do not copy (sync/GitLab/multi-account)

- **Sync engine:** all of `Services/SyncService*.swift` (12 partials), `CacheUpsertCore*`,
  `WorkItemCacheActor*`, `MetadataScope`, `SyncPayloads`, `WidgetDataService`, `NetworkStatus`,
  `SpotlightIndexingService`, `ImageCacheService`; models `PendingMutation`, `WorkItem*`,
  `EmbeddedTypes`; `AppCoordinator+*Sync/Prefetch/DataLifecycle`.
  *(Steal only the `StoreRecoveryService` move-aside idea — §3.)*
- **GitLab API layer:** entire `99issues/Networking/` (21 files), all `Models/GitLab*.swift`.
- **Multi-account/auth:** `AccountConfig`, `APIClientManager`, `AppManifestService`, the `*Resolver`
  utilities, account screens & tests. *(Keep only the generic `KeychainService` wrapper — §3.)*
- **Widget & Share extensions:** GitLab-specific. Only revisit if Yaht wants its own habit widget
  (the GitHub-style activity widget is in-app, not necessarily a home-screen WidgetKit widget — TBD).

---

## TL;DR reuse checklist

- [ ] Copy `.gitlab-ci.yml`, `scripts/asc`, `ci_scripts/ci_post_xcodebuild.sh`, `.gitignore`, xcconfig pattern
- [ ] Re-point ASC IDs (asc lines 22-31) + Sentry/ASC CI variables to Yaht
- [ ] Mirror folder structure + App entry (ModelContainer + recovery + test guard)
- [ ] Versioned SwiftData schema + **CloudKit mirroring** from day one (replaces the sync engine)
- [ ] Import Liquid Glass gotchas + `Color+Hex` + generic components
- [ ] Lock always-dark (`UIUserInterfaceStyle = Dark`) + build the Cyberdream palette (design phase)
- [ ] Build notifications fresh (calendar triggers, custom tones, week/weekend, 64-limit budgeting)
- [ ] Import `conventions.md` + protocol-mock testing pattern
