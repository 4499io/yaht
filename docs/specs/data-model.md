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
| `colorHex` | `String` | `""` | Cyberdream palette hue; blends into global activity widget |
| `createdAt` | `Date` | `Date()` | |
| `isArchived` | `Bool` | `false` | soft-delete / hide without losing history |
| `sortOrder` | `Int` | `0` | manual ordering in the list |
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

### `HabitLog`  (one completion record per habit per day)
| Property | Type | Default | Notes |
|---|---|---|---|
| `id` | `UUID` | `UUID()` | |
| `day` | `Date` | `Date()` | normalized to `startOfDay` (local) — app enforces one-per-day |
| `completedAt` | `Date` | `Date()` | actual timestamp of the tap |
| `habit` | `Habit?` | `nil` | inverse |

> Binary done/not-done per day (typical habit-tracker model). A missing `HabitLog` for a due day =
> not done. This keeps the activity grid a simple per-day lookup.

---

## Enums (stored as raw values)

```
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
(interprets schedule), `isCompleted(on:)` (queries logs). These live in a `Habit+Logic.swift`
extension, unit-tested.

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
`Models/AppSchema.swift`. ModelContainer built in `YahtApp` with explicit store URL in Application
Support, `cloudKitDatabase: .automatic`, backup-exclude + move-aside recovery.

## Service layer

`HabitStore` protocol (+ `HabitStoreProtocol`) with a SwiftData impl and a configurable mock
(spy flags + stubbed results, `throw MockError.notConfigured` default — LESSONS §5):
- `create/update/delete/archive(Habit)`, `reorder`, `toggleCompletion(habit:day:)`,
  `logs(for:in:)`, `allActiveHabits()`.
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
  `isCompleted(on:)`; `color` parsing.
- `HabitStore` (SwiftData, in-memory container): create→fetch, toggle idempotency (no dup log for
  same day), cascade delete removes logs+reminders, archive hides from `allActiveHabits`.

---

## Resolved decisions (2026-07-09)
1. **Completion = binary** done/not-done per habit per day. A count-based target may come in a later
   schema version if needed.
2. **All four `ScheduleKind`s** ship in v1: `daily`, `specificWeekdays`, `everyNDays`, `timesPerWeek`.
   `timesPerWeek` is a flexible target — the grid shows progress toward N; no specific day is "missed".
3. **Multiple reminders per habit** — each with `everyDay` / `weekdaysOnly` / `weekendsOnly` scope.
4. **CloudKit container** `iCloud.io.4499.yaht`.
