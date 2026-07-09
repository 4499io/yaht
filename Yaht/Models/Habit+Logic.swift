import Foundation
import SwiftUI

extension Habit {
    /// Resolved display color, falling back to the accent color for bad hex.
    var color: Color { Color(hex: colorHex) ?? .accentColor }

    /// The tally recorded on `date` (0 if there is no log for that day).
    func dayCount(on date: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: date)
        guard let logs else { return 0 }
        for log in logs where calendar.startOfDay(for: log.day) == start {
            return log.count
        }
        return 0
    }

    /// Whether the habit is satisfied for `date`.
    /// Binary: any log with count >= 1. Count: dayCount >= dailyTarget.
    func isCompleted(on date: Date, calendar: Calendar = .current) -> Bool {
        switch habitKind {
        case .binary:
            return dayCount(on: date, calendar: calendar) >= 1
        case .count:
            let target = max(dailyTarget, 1)
            return dayCount(on: date, calendar: calendar) >= target
        }
    }

    /// Fractional progress toward completion for `date`, clamped to 0...1.
    func progress(on date: Date, calendar: Calendar = .current) -> Double {
        switch habitKind {
        case .binary:
            return isCompleted(on: date, calendar: calendar) ? 1 : 0
        case .count:
            let target = max(dailyTarget, 1)
            let value = Double(dayCount(on: date, calendar: calendar)) / Double(target)
            return min(max(value, 0), 1)
        }
    }

    /// Whether the habit is scheduled to be done on `date`, per `scheduleKind`.
    func isDue(on date: Date, calendar: Calendar = .current) -> Bool {
        switch schedule {
        case .daily:
            return true

        case .specificWeekdays:
            let weekday = calendar.component(.weekday, from: date) // 1...7
            let bit = 1 << (weekday - 1)
            return (scheduleDaysMask & bit) != 0

        case .everyNDays:
            let interval = max(intervalDays, 1)
            let startCreated = calendar.startOfDay(for: createdAt)
            let startDate = calendar.startOfDay(for: date)
            let days = calendar.dateComponents([.day], from: startCreated, to: startDate).day ?? 0
            guard days >= 0 else { return false }
            return days % interval == 0

        case .timesPerWeek:
            // Due on any day until the weekly target has been met.
            guard weeklyTarget > 0 else { return false }
            return completedDaysThisWeek(containing: date, calendar: calendar) < weeklyTarget
        }
    }

    /// Number of completed days in the calendar week containing `date`.
    private func completedDaysThisWeek(containing date: Date, calendar: Calendar) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        guard let logs else { return 0 }
        var seen = Set<Date>()
        for log in logs {
            let start = calendar.startOfDay(for: log.day)
            guard start >= interval.start && start < interval.end else { continue }
            if isCompleted(on: log.day, calendar: calendar) {
                seen.insert(start)
            }
        }
        return seen.count
    }
}
