import Foundation

/// Lifetime completion figures computed from a habit's logs.
struct HabitStats: Equatable {
    let totalCompleted: Int
    let last30Percent: Int

    init(habit: Habit, today: Date = Date(), calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: today)
        let completed = habit.completedDays(calendar: calendar)
        totalCompleted = completed.count

        var last30 = 0
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            if completed.contains(day) { last30 += 1 }
        }
        last30Percent = Int((Double(last30) / 30.0 * 100).rounded())
    }
}

/// One week's goal for a habit, after excluding days before the habit existed
/// and paused days.
///
/// - Times-a-week habits need their weekly target, scaled down to the share of
///   the week that is not paused.
/// - Other schedules need every due day, except that one rest day is allowed
///   when five or more days are due (6 of 7 daily, 4 of 5 on weekdays).
///
/// A week with nothing due (fully paused, before the habit existed, or no
/// scheduled days) is *neutral*: it neither extends nor breaks a streak.
struct WeekGoal: Equatable {
    /// Days done in the week.
    let completed: Int
    /// Days needed to meet the goal.
    let required: Int
    /// Rest days the goal allows (0 or 1).
    let restDays: Int

    var isNeutral: Bool { required == 0 }
    var isMet: Bool { !isNeutral && completed >= required }
    var fraction: Double { isNeutral ? 0 : min(Double(completed) / Double(required), 1) }
}

/// Weeks in a row a habit met its weekly goal.
struct WeeklyStreak: Equatable {
    /// Includes the current week once its goal is met; an unfinished current
    /// week never breaks the streak.
    let current: Int
    /// Longest run ever, current one included.
    let best: Int
}

extension Habit {
    /// Start-of-day dates on which the habit was completed.
    func completedDays(calendar: Calendar = .current) -> Set<Date> {
        var days = Set<Date>()
        for log in logs ?? [] where isCompleted(on: log.day, calendar: calendar) {
            days.insert(calendar.startOfDay(for: log.day))
        }
        return days
    }

    /// The goal for the week containing `date`.
    func weekGoal(containing date: Date = Date(), calendar: Calendar = .current) -> WeekGoal {
        weekGoal(containing: date, completedDays: completedDays(calendar: calendar), calendar: calendar)
    }

    /// Current and best weekly streak as of `today`.
    func weeklyStreak(today: Date = Date(), calendar: Calendar = .current) -> WeeklyStreak {
        let completed = completedDays(calendar: calendar)
        guard
            let currentWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
            let firstWeek = calendar.dateInterval(of: .weekOfYear, for: createdAt)?.start,
            firstWeek <= currentWeek
        else { return WeeklyStreak(current: 0, best: 0) }

        // Oldest to newest; the current week counts once met and never breaks.
        var run = 0
        var best = 0
        var week = firstWeek
        while week <= currentWeek {
            let goal = weekGoal(containing: week, completedDays: completed, calendar: calendar)
            if goal.isMet {
                run += 1
            } else if !goal.isNeutral && week < currentWeek {
                run = 0
            }
            best = max(best, run)
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: week) else { break }
            week = next
        }
        return WeeklyStreak(current: run, best: best)
    }

    /// Short schedule description, e.g. "Every day" or "3× a week".
    var scheduleSummary: String {
        switch schedule {
        case .daily:
            return String(localized: "Every day")
        case .specificWeekdays:
            let symbols = Calendar.current.shortWeekdaySymbols
            let days = (1...7).filter { scheduleDaysMask & (1 << ($0 - 1)) != 0 }.map { symbols[$0 - 1] }
            return days.isEmpty ? String(localized: "No days chosen") : days.joined(separator: ", ")
        case .everyNDays:
            return String(localized: "Every \(max(intervalDays, 1)) days")
        case .timesPerWeek:
            return String(localized: "\(max(weeklyTarget, 1))× a week")
        }
    }

    /// Daily goal for a count habit, e.g. "8 glasses"; `nil` for yes/no habits.
    var goalSummary: String? {
        guard habitKind == .count else { return nil }
        let target = max(dailyTarget, 1)
        guard let unit, !unit.isEmpty else { return String(localized: "Goal \(target)") }
        return "\(target) \(unit)"
    }

    /// Whether the habit belongs on today's list: due, or already done.
    func isOnToday(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        isDue(on: date, calendar: calendar) || isCompleted(on: date, calendar: calendar)
    }

    private func weekGoal(containing date: Date, completedDays: Set<Date>, calendar: Calendar) -> WeekGoal {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return WeekGoal(completed: 0, required: 0, restDays: 0)
        }
        let created = calendar.startOfDay(for: createdAt)
        var completed = 0
        var activeDays = 0
        var dueDays = 0
        var day = week.start
        while day < week.end {
            if completedDays.contains(day) { completed += 1 }
            if day >= created, !isPaused(on: day, calendar: calendar) {
                activeDays += 1
                if schedule != .timesPerWeek, isDue(on: day, calendar: calendar) { dueDays += 1 }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        if schedule == .timesPerWeek {
            let target = max(weeklyTarget, 1)
            let required = Int((Double(target) * Double(activeDays) / 7).rounded(.up))
            return WeekGoal(completed: completed, required: required, restDays: 0)
        }
        let restDays = dueDays >= 5 ? 1 : 0
        return WeekGoal(completed: completed, required: dueDays - restDays, restDays: restDays)
    }
}
