# Yaht — Build Plan (small specs, iterate)

Repo: `github.com/4499io/yaht` (moved from GitLab; steps below that mention GitLab, MRs or
`.gitlab-ci.yml` are history, CI is now `.github/workflows/`) · iPhone-only · always-dark Cyberdream Liquid Glass ·
SwiftData + CloudKit (no custom sync). Companion: [`LESSONS.md`](./LESSONS.md).

Philosophy: each step is a **small spec** merged as its own MR, reviewed before the next. Stop points
marked 🛑 = get your feedback before proceeding.

---

## Open questions (need answers before/early)

1. **How do we create the initial `.xcodeproj`?** No Xcode/macOS on this VPS. Options:
   - (a) You generate an empty SwiftUI app project on your Mac + push it, I fill in everything after.
   - (b) I hand-author `project.pbxproj` + declare targets (fragile, but done once; CI validates it).
   - (c) Adopt **XcodeGen** (`project.yml`) or **Tuist** so the project is generated from a spec — you
     run the generator on your Mac / in CI. Cleaner long-term, new dependency.
   → **My rec: (a) for speed, or (c) if you want reproducible project config.** Blocks all code work.
2. **Cyberdream palette resolution.** Neon-on-black vs "never overwhelming / no bright flash in dim
   rooms." I'll propose a muted-Cyberdream token set (deep near-black bg, desaturated accents) for
   your sign-off in Step 3.
3. **GitHub-style activity widget = in-app view** (assumed) vs also a home-screen **WidgetKit** widget.
   v1 assume in-app only; WidgetKit later. OK?
4. **Bundle ID** — `io.4499.yaht`? (99issues used `com.4499.99issues`.) Confirm prefix.

---

## Sequence

### Step 0 — Repo bootstrap 🛑
- `git init`, set per-repo identity (`user.name`, `user.email = gitlab@4499.io`), wire remote
  `gitlab.com/4499.io/yaht/xcode`, initial commit with `docs/` + `.gitignore`.
- Copy CI/CD bundle (LESSONS §1): `.gitlab-ci.yml`, `scripts/asc`, `ci_scripts/`, `Configuration/`
  (xcconfig with `#include? Local.xcconfig`). **Placeholders** for ASC/Sentry IDs — you fill secrets.
- **Deliverable:** a repo that has infra + docs, no app yet. → your review.

### Step 1 — Project skeleton (blocked on Open Q#1)
- Create `.xcodeproj` (per Q#1 decision), targets: `Yaht`, `YahtTests`.
- Build settings: iOS 26 deploy target, Swift 6, `UIUserInterfaceStyle = Dark`, bundle IDs,
  iCloud/CloudKit + data-protection entitlements.
- App entry: `ModelContainer` (explicit store URL, migration plan, backup-exclude, non-destructive startup retry,
  `isRunningTests` guard) + CloudKit config. Empty `SchemaV1`.
- `.gitlab-ci.yml` goes green on an empty test. → review.

### Step 2 — Data model spec 🛑
- `@Model Habit` (emoji, name, colorHex, schedule, notification config, createdAt) + `HabitLog`
  (habit ref, date, completed). Versioned `SchemaV1`. CloudKit-compatible (optionals, no unique
  constraints CloudKit rejects).
- Unit tests for model + a `HabitStore` service behind a protocol (mock pattern from LESSONS §5).
- **Small spec doc `docs/specs/data-model.md` first → your review before code.**

### Step 3 — Design foundation 🛑
- `docs/specs/design-system.md`: Cyberdream token set (bg, surfaces, text, accents), typography,
  spacing, material usage rules (LESSONS §2). **Palette proposal for sign-off.**
- Implement `Theme`/`Color+Hex` + a habit-color palette (Cyberdream hues). One demo screen using
  glass cards/pills to validate the look. → your review (visual, likely needs a device screenshot).

### Step 4 — Core screens (iterate, one MR each)
- Habit list (activity-widget teaser), Add/Edit habit sheet (emoji + color + schedule), Habit detail
  with per-habit activity grid. Thin views, `@Observable` VMs, tests each.

### Step 5 — Notifications (greenfield, LESSONS §4)
- `docs/specs/notifications.md` first. Then `NotificationScheduler` service: calendar triggers,
  week/weekend fan-out, custom tones, stable IDs, cancel-on-edit, 64-limit budgeting. Heavy tests.

### Step 6 — GitHub-style activity widget
- Global blended-color contribution grid + per-habit grids. Perf-conscious (many cells).

### Step 7 — Polish / onboarding / App Store prep
- Onboarding slideshow (reuse `SlideshowView`), settings, iCloud status, App Store texts, screenshots.
- First TestFlight via the copied `asc` pipeline.

---

## What I'll do next (pending your OK)
Start **Step 0** — bootstrap the repo + drop in the CI/CD bundle with placeholder IDs. Nothing
irreversible; all reviewable in one MR. I'll pause after for feedback.
