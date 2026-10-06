import Foundation
import Testing
@testable import Yaht

/// Streaks, week progress and summaries, on a fixed UTC Gregorian calendar
/// whose weeks start on Monday.
@MainActor
struct HabitStatsTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        if let utc = TimeZone(identifier: "UTC") { cal.timeZone = utc }
        cal.firstWeekday = 2
        return cal
    }

    /// 2025-01-06 is a Monday.
    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2025, month: 1, day: day, hour: 12)) ?? .distantPast
    }

    private func habit(_ kind: ScheduleKind = .daily, weeklyTarget: Int = 0, doneOn days: [Int]) -> Habit {
        let logs = days.map { HabitLog(day: date($0), count: 1) }
        let habit = Habit(createdAt: date(1), scheduleKind: kind, weeklyTarget: weeklyTarget, logs: logs)
        logs.forEach { $0.habit = habit }
        return habit
    }

    @Test func streaksCountConsecutiveDaysAndAllowTodayPending() {
        let stats = HabitStats(habit: habit(doneOn: [2, 3, 5, 6, 7]), today: date(8), calendar: calendar)
        #expect(stats.currentStreak == 3)
        #expect(stats.bestStreak == 3)
        #expect(stats.totalCompleted == 5)
    }

    @Test func streakBreaksAfterAMissedDay() {
        let stats = HabitStats(habit: habit(doneOn: [5, 6]), today: date(8), calendar: calendar)
        #expect(stats.currentStreak == 0)
        #expect(stats.bestStreak == 2)
    }

    @Test func timesPerWeekProgressUsesTheWeeklyTarget() {
        let week = habit(.timesPerWeek, weeklyTarget: 3, doneOn: [5, 6, 7]).weekProgress(containing: date(8), calendar: calendar)
        #expect(week == WeekProgress(completed: 2, target: 3))
        #expect(!week.isMet)
        #expect(abs(week.fraction - 2.0 / 3.0) < 0.0001)
    }

    @Test func dailyProgressCountsTheWholeWeek() {
        let week = habit(doneOn: [6, 7, 8, 9, 10, 11, 12]).weekProgress(containing: date(8), calendar: calendar)
        #expect(week == WeekProgress(completed: 7, target: 7))
        #expect(week.isMet)
    }

    @Test func onTodayIncludesDoneHabitsThatAreNoLongerDue() {
        let met = habit(.timesPerWeek, weeklyTarget: 1, doneOn: [8])
        #expect(!met.isDue(on: date(8), calendar: calendar))
        #expect(met.isOnToday(date(8), calendar: calendar))
        #expect(!met.isOnToday(date(9), calendar: calendar))
    }

    @Test func goalSummaryOnlyForCountHabits() {
        #expect(Habit(kind: .binary).goalSummary == nil)
        #expect(Habit(kind: .count, dailyTarget: 8, unit: "glasses").goalSummary == "8 glasses")
    }
}
