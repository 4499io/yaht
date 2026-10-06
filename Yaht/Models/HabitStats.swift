import Foundation

/// Streak and completion figures computed from a habit's logs.
struct HabitStats: Equatable {
    let currentStreak: Int
    let bestStreak: Int
    let totalCompleted: Int
    let last30Percent: Int

    init(habit: Habit, today: Date = Date(), calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: today)

        var completedSet = Set<Date>()
        for log in habit.logs ?? [] where habit.isCompleted(on: log.day, calendar: calendar) {
            completedSet.insert(calendar.startOfDay(for: log.day))
        }
        let completed = completedSet.sorted()
        totalCompleted = completed.count

        // Current streak: walk back from today (or yesterday, if today is pending).
        var streak = 0
        var cursor = today
        if !completedSet.contains(today) {
            cursor = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        }
        while completedSet.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        currentStreak = streak

        // Best streak: longest run of consecutive completed days.
        var best = 0
        var run = 0
        var expected: Date?
        for day in completed {
            if let expected, expected == day {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            expected = calendar.date(byAdding: .day, value: 1, to: day)
        }
        bestStreak = best

        // Completion rate over the trailing 30 days.
        var last30 = 0
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            if completedSet.contains(day) { last30 += 1 }
        }
        last30Percent = Int((Double(last30) / 30.0 * 100).rounded())
    }
}

/// Progress toward this week's goal: completed days against the target.
struct WeekProgress: Equatable {
    let completed: Int
    let target: Int

    var fraction: Double { target > 0 ? min(Double(completed) / Double(target), 1) : 0 }
    var isMet: Bool { target > 0 && completed >= target }
}

extension Habit {
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

    /// Completed days in the week containing `date`, against the week's goal:
    /// the weekly target for "times a week" habits, otherwise the days due.
    func weekProgress(containing date: Date = Date(), calendar: Calendar = .current) -> WeekProgress {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return WeekProgress(completed: 0, target: 0)
        }
        var completed = 0
        var due = 0
        var day = week.start
        while day < week.end {
            if isCompleted(on: day, calendar: calendar) { completed += 1 }
            if schedule != .timesPerWeek, isDue(on: day, calendar: calendar) { due += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        let target = schedule == .timesPerWeek ? max(weeklyTarget, 1) : due
        return WeekProgress(completed: completed, target: target)
    }

    /// Whether the habit belongs on today's list: due, or already done.
    func isOnToday(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        isDue(on: date, calendar: calendar) || isCompleted(on: date, calendar: calendar)
    }
}
