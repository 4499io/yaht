import Foundation

// MARK: - Pure, unit-testable helpers
//
// These are deliberately free of any `UNUserNotificationCenter` usage so tests
// can exercise the identifier format and scope fan-out without notification
// entitlements. Marked `nonisolated` so they are callable from any context.
extension NotificationScheduler {

    /// Maximum number of pending requests we will keep scheduled at once.
    /// The system hard limit is 64; we stay well under it to leave headroom.
    nonisolated static var pendingBudget: Int { 60 }

    /// The set of `Calendar` weekdays a reminder scope fans out to.
    ///
    /// A `nil` element means "no weekday constraint" — a single daily trigger.
    /// - `.everyDay`      -> `[nil]`            (1 trigger)
    /// - `.weekdaysOnly`  -> `[2, 3, 4, 5, 6]`  (Mon...Fri, 5 triggers)
    /// - `.weekendsOnly`  -> `[1, 7]`           (Sun & Sat, 2 triggers)
    nonisolated static func weekdays(for scope: ReminderScope) -> [Int?] {
        switch scope {
        case .everyDay: return [nil]
        case .weekdaysOnly: return [2, 3, 4, 5, 6]
        case .weekendsOnly: return [1, 7]
        }
    }

    /// The weekdays a reminder fires on. A habit scheduled on specific days
    /// fires only on those days, whatever the reminder's own scope; other
    /// habits follow the reminder's scope.
    nonisolated static func reminderWeekdays(scope: ReminderScope, habitWeekdays: [Int]?) -> [Int?] {
        guard let habitWeekdays else { return weekdays(for: scope) }
        return habitWeekdays.sorted().map { Optional($0) }
    }

    /// Hourly nudges stop after this hour, so none fire late at night.
    nonisolated static var lastNudgeHour: Int { 22 }

    /// One-shot nudge times for a reminder that repeats hourly: every hour
    /// after the reminder, at its minute, through `lastNudgeHour`, on each
    /// nudge day the reminder fires on, later than `now`, earliest first.
    nonisolated static func nudgeDates(
        hour: Int,
        minute: Int,
        weekdays: [Int?],
        days: [Date],
        now: Date,
        calendar: Calendar
    ) -> [Date] {
        guard hour < lastNudgeHour else { return [] }
        return days.filter { day in
            weekdays.contains(nil) || weekdays.contains(calendar.component(.weekday, from: day))
        }.flatMap { day in
            ((hour + 1)...lastNudgeHour).compactMap {
                calendar.date(bySettingHour: $0, minute: minute, second: 0, of: day)
            }
        }.filter { $0 > now }.sorted()
    }

    /// Identifier of a one-shot nudge: `habit-<habitID>-<reminderID>-nudge-<yyyyMMddHHmm>`.
    nonisolated static func nudgeIdentifier(habitID: UUID, reminderID: UUID, date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let stamp = String(
            format: "%04d%02d%02d%02d%02d",
            c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0
        )
        return "\(identifierPrefix(forHabitID: habitID))\(reminderID.uuidString)-nudge-\(stamp)"
    }

    /// Stable request identifier: `habit-<habitID>-<reminderID>-<weekday-or-daily>`.
    /// A `nil` weekday renders as `daily`.
    nonisolated static func identifier(
        habitID: UUID,
        reminderID: UUID,
        weekday: Int?
    ) -> String {
        let suffix = weekday.map(String.init) ?? "daily"
        return "\(identifierPrefix(forHabitID: habitID))\(reminderID.uuidString)-\(suffix)"
    }

    /// Shared prefix for every request belonging to a habit, used for bulk cancel.
    nonisolated static func identifierPrefix(forHabitID id: UUID) -> String {
        "habit-\(id.uuidString)-"
    }
}
