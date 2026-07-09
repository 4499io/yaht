import Foundation

/// Whether a habit is a simple yes/no or a counted quantity.
enum HabitKind: String, Codable, CaseIterable, Sendable {
    case binary
    case count
}

/// How often a habit is scheduled to be due.
enum ScheduleKind: String, Codable, CaseIterable, Sendable {
    case daily
    case specificWeekdays
    case everyNDays
    case timesPerWeek
}

/// Which days a reminder should fire on.
enum ReminderScope: String, Codable, CaseIterable, Sendable {
    case everyDay
    case weekdaysOnly
    case weekendsOnly
}
