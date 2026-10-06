# Spec — Data Model (Step 2)

Status: **DRAFT for review** · Companion: [`../PLAN.md`](../PLAN.md), [`../LESSONS.md`](../LESSONS.md)

Goal: SwiftData models for Yaht, mirrored to iCloud via **CloudKit** (`.automatic`). No custom
sync. This step defines the schema + a `HabitStore` service (protocol + mock), with unit tests.

---

## CloudKit constraints (these shape every decision)

SwiftData + CloudKit mirroring imposes hard rules — violating them crashes container init:
1. **Every non-optional property needs a default value.** (CloudKit has no notion of required.)
2. **No `@Attribute(.unique)`.** Identity/uniqueness is enforced in app logic, not the store.
3. **Every relationship is optional and needs an inverse.** Delete rules allowed, but both sides optional.
4. **No `.externalStorage` surprises**, enums stored as raw `String`/`Int`.
5. Container config: `ModelConfiguration(..., cloudKitDatabase: .automatic)` + iCloud/CloudKit
   entitlement + `remote-notification` background mode (added this step, see §Entitlements).

---

## Models

### `Habit`
| Property | Type | Default | Notes |
|---|---|---|---|
| `id` | `UUID` | `UUID()` | app-level identity (not a unique constraint) |
| `name` | `String` | `""` | |
| `emoji` | `String` | `""` | habit identifier glyph |
| `colorHex` | `String` | `""` | Habit palette hue (Gruvbox, `Theme.habitColors`); blends into the global activity grid |
| `createdAt` | `Date` | `Date()` | |
| `isArchived` | `Bool` | `false` | soft-delete / hide without losing history |
| `sortOrder` | `Int` | `0` | manual ordering in the list |
| `kind` | `String` | `"binary"` | raw of `HabitKind` — per-habit tracking mode (binary vs count) |
| `dailyTarget` | `Int` | `1` | count-based goal per due day (e.g. 8 glasses). `1` for binary |
| `unit` | `String?` | `nil` | optional count label for UI ("glasses", "reps"); `nil` for binary |
| `scheduleKind` | `String` | `"daily"` | raw of `ScheduleKind` |
| `scheduleDaysMask` | `Int` | `0` | weekday bitmask when `scheduleKind == specificWeekdays` (bit0=Sun…bit6=Sat) |
| `intervalDays` | `Int` | `1` | when `scheduleKind == everyNDays` |
| `weeklyTarget` | `Int` | `0` | when `scheduleKind == timesPerWeek` |
| `soundName` | `String?` | `nil` | custom notification tone; `nil` = default |
| `reminders` | `[Reminder]?` | `nil` | to-many, inverse `Reminder.habit`, cascade delete |
| `logs` | `[HabitLog]?` | `nil` | to-many, inverse `HabitLog.habit`, cascade delete |

### `Reminder`  (per-habit notification time; drives Step 5 scheduling)
| Property | Type | Default | Notes |
|---|---|---|---|
| `id` | `UUID` | `UUID()` | |
| `hour` | `Int` | `9` | 0–23 |
| `minute` | `Int` | `0` | 0–59 |
| `scope` | `String` | `"everyDay"` | raw of `ReminderScope` — models the week/weekend requirement |
| `isEnabled` | `Bool` | `true` | |
| `habit` | `Habit?` | `nil` | inverse |

### `HabitLog`  (one record per habit per day, for both kinds)
| Property | Type | Default | Notes |
|---|---|---|---|
| `id` | `UUID` | `UUID()` | |
| `day` | `Date` | `Date()` | normalized to `startOfDay` (local) — app enforces one-per-day |
| `count` | `Int` | `1` | **binary:** `1` = done. **count:** running total for the day (e.g. 5 of 8) |
| `updatedAt` | `Date` | `Date()` | timestamp of the last tap/increment |
| `habit` | `Habit?` | `nil` | inverse |

> **One `HabitLog` per habit per day** regardless of kind. Missing log for a due day = not done.
> - **Binary** habit: log exists with `count == 1` ⇒ done.
> - **Count** habit: `count` accumulates; **completed** when `count >= habit.dailyTarget`. The
>   activity grid can render a *partial* fill from `count / dailyTarget`.
>
> Keeping the log shape identical for both kinds means the grid, streaks, and store API stay uniform;
> only the "is this day complete?" predicate branches on `habit.kind`.

---

## Enums (stored as raw values)

```
enum HabitKind: String, Codable, CaseIterable {
    case binary  // done / not-done per day
    case count   // accumulate toward dailyTarget per day (e.g. 8 glasses of water)
}

enum ScheduleKind: String, Codable, CaseIterable {
    case daily            // every day
    case specificWeekdays // scheduleDaysMask
    case everyNDays       // intervalDays
    case timesPerWeek     // weeklyTarget (flexible; any N days/week)
}

enum ReminderScope: String, Codable, CaseIterable {
    case everyDay
    case weekdaysOnly   // Mon–Fri
    case weekendsOnly   // Sat–Sun
}
```

`Habit` gets computed helpers (non-persisted): `color: Color` (from `colorHex`), `isDue(on:)`
(interprets schedule), `isCompleted(on:)` (binary: log exists; count: `dayCount >= dailyTarget`),
and `progress(on:) -> Double` (0…1; binary is 0 or 1, count is `dayCount / dailyTarget` clamped —
drives partial grid fills). These live in a `Habit+Logic.swift` extension, unit-tested.

---

## Schema & migration (from day one — LESSONS §3)

```
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Habit.self, Reminder.self, HabitLog.self] }
}
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
```
`Models/AppSchema.swift`. `PersistentStoreLoader` opens the explicit store URL in Application
Support with `cloudKitDatabase: .automatic`, then retries the same URL with `.none` if startup
fails. Neither attempt renames or deletes the database or its sidecars. If both fail, `YahtApp`
shows a blocking error screen with Retry, preserving the existing data for recovery. Writable
in-memory containers are reserved for tests; production does not silently lose newly entered data.

## Service layer

`HabitStore` protocol (+ `HabitStoreProtocol`) with a SwiftData impl and a configurable mock
(spy flags + stubbed results, `throw MockError.notConfigured` default — LESSONS §5):
- `create/update/delete/archive(Habit)`, `reorder`, `logs(for:in:)`, `allActiveHabits()`.
- **Completion mutation branches on kind:** `toggleCompletion(habit:day:)` for binary (create/remove
  the day's log); `increment(habit:day:by:)` / `setCount(habit:day:to:)` for count (upsert the day's
  log, clamp at ≥0). Both keep the one-log-per-day invariant.
Views never touch `modelContext` directly (thin views rule).

## Entitlements / capabilities added this step
- `Yaht.entitlements`: `com.apple.developer.icloud-container-identifiers` = `iCloud.io.4499.yaht`,
  `com.apple.developer.icloud-services` = `CloudKit`, keep data-protection.
- Info.plist / build: `UIBackgroundModes` = `remote-notification` (CloudKit sync push).
- **Your ASC/portal task:** enable **iCloud + CloudKit** (and create the `iCloud.io.4499.yaht`
  container) and **Push Notifications** capability on the `io.4499.yaht` App ID, or the Xcode Cloud
  archive will fail signing later. (CI test job is unaffected — signing disabled.)

## Tests
- `Habit+Logic`: `isDue(on:)` across all four `ScheduleKind`s incl. weekday-mask + everyN edge cases;
  `isCompleted(on:)` and `progress(on:)` for **both** kinds (binary 0/1; count below/at/over target);
  `color` parsing.
- `HabitStore` (SwiftData, in-memory container): create→fetch; binary toggle idempotency (no dup log
  for same day); count increment/setCount upsert (single log accrues, clamps at 0, crossing target
  flips `isCompleted`); cascade delete removes logs+reminders; archive hides from `allActiveHabits`.

---

## Resolved decisions (2026-07-09)
1. **Two habit kinds, chosen per habit** via `Habit.kind` (`HabitKind`): **binary** (done/not-done) and
   **count** (accumulate toward `dailyTarget`, e.g. 8 glasses). Same `HabitLog` shape for both; only the
   "day complete?" predicate and the completion mutation branch on kind.
2. **All four `ScheduleKind`s** ship in v1: `daily`, `specificWeekdays`, `everyNDays`, `timesPerWeek`.
   `timesPerWeek` is a flexible target — the grid shows progress toward N; no specific day is "missed".
3. **Multiple reminders per habit** — each with `everyDay` / `weekdaysOnly` / `weekendsOnly` scope.
4. **CloudKit container** `iCloud.io.4499.yaht`.
