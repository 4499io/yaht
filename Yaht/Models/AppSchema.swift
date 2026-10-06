import Foundation
import SwiftData

/// The schema the app runs on. Update together with ``AppMigrationPlan``.
typealias CurrentSchema = SchemaV2

/// Version 1 of the persisted schema, frozen as it shipped: habits, reminders
/// and logs. These nested copies must never change; they let SwiftData
/// recognise version 1 stores and migrate them.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Habit.self, Reminder.self, HabitLog.self]
    }

    @Model
    final class Habit {
        var id: UUID = UUID()
        var name: String = ""
        var emoji: String = ""
        var colorHex: String = ""
        var createdAt: Date = Date()
        var isArchived: Bool = false
        var sortOrder: Int = 0
        var kind: String = HabitKind.binary.rawValue
        var dailyTarget: Int = 1
        var unit: String?
        var scheduleKind: String = ScheduleKind.daily.rawValue
        var scheduleDaysMask: Int = 0
        var intervalDays: Int = 1
        var weeklyTarget: Int = 0
        var soundName: String?

        @Relationship(deleteRule: .cascade, inverse: \Reminder.habit)
        var reminders: [Reminder]?

        @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
        var logs: [HabitLog]?

        init() {}
    }

    @Model
    final class Reminder {
        var id: UUID = UUID()
        var hour: Int = 9
        var minute: Int = 0
        var scope: String = ReminderScope.everyDay.rawValue
        var isEnabled: Bool = true
        var habit: Habit?

        init() {}
    }

    @Model
    final class HabitLog {
        var id: UUID = UUID()
        var day: Date = Date()
        var count: Int = 1
        var updatedAt: Date = Date()
        var habit: Habit?

        init() {}
    }
}

/// Version 2 adds ``HabitPause`` and `Habit.pauses`. Purely additive, so
/// version 1 stores migrate in place (and the CloudKit schema only grows).
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Habit.self, Reminder.self, HabitLog.self, HabitPause.self]
    }
}

/// Migration plan across schema versions.
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}
