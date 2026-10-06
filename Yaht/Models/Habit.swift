import Foundation
import SwiftData

/// A user-defined habit. Stored via SwiftData; all stored properties carry
/// defaults so the schema is CloudKit-compatible later (optional relationships).
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
    /// bit0=Sunday ... bit6=Saturday (Calendar weekday 1..7 => bit (wd-1)).
    var scheduleDaysMask: Int = 0
    var intervalDays: Int = 1
    var weeklyTarget: Int = 0

    var soundName: String?

    @Relationship(deleteRule: .cascade, inverse: \Reminder.habit)
    var reminders: [Reminder]?

    @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
    var logs: [HabitLog]?

    @Relationship(deleteRule: .cascade, inverse: \HabitPause.habit)
    var pauses: [HabitPause]?

    init(
        id: UUID = UUID(),
        name: String = "",
        emoji: String = "",
        colorHex: String = "",
        createdAt: Date = Date(),
        isArchived: Bool = false,
        sortOrder: Int = 0,
        kind: HabitKind = .binary,
        dailyTarget: Int = 1,
        unit: String? = nil,
        scheduleKind: ScheduleKind = .daily,
        scheduleDaysMask: Int = 0,
        intervalDays: Int = 1,
        weeklyTarget: Int = 0,
        soundName: String? = nil,
        reminders: [Reminder]? = nil,
        logs: [HabitLog]? = nil,
        pauses: [HabitPause]? = nil
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.sortOrder = sortOrder
        self.kind = kind.rawValue
        self.dailyTarget = dailyTarget
        self.unit = unit
        self.scheduleKind = scheduleKind.rawValue
        self.scheduleDaysMask = scheduleDaysMask
        self.intervalDays = intervalDays
        self.weeklyTarget = weeklyTarget
        self.soundName = soundName
        self.reminders = reminders
        self.logs = logs
        self.pauses = pauses
    }

    /// Non-persisted view of `kind`. Falls back to `.binary` for bad data.
    var habitKind: HabitKind {
        get { HabitKind(rawValue: kind) ?? .binary }
        set { kind = newValue.rawValue }
    }

    /// Non-persisted view of `scheduleKind`. Falls back to `.daily`.
    var schedule: ScheduleKind {
        get { ScheduleKind(rawValue: scheduleKind) ?? .daily }
        set { scheduleKind = newValue.rawValue }
    }
}
