import Foundation
import Testing
@testable import Yaht

/// Week goals, weekly streaks, pauses and summaries, on a fixed UTC Gregorian
/// calendar whose weeks start on Monday.
@MainActor
struct HabitStatsTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        if let utc = TimeZone(identifier: "UTC") { cal.timeZone = utc }
        cal.firstWeekday = 2
        return cal
    }

    /// January 2025: the 6th, 13th, 20th and 27th are Mondays.
    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2025, month: 1, day: day, hour: 12)) ?? .distantPast
    }

    private func habit(
        _ kind: ScheduleKind = .daily,
        weeklyTarget: Int = 0,
        mask: Int = 0,
        createdOn created: Int = 6,
        doneOn days: [Int],
        paused: [(Int, Int)] = []
    ) -> Habit {
        let logs = days.map { HabitLog(day: date($0), count: 1) }
        let pauses = paused.map { HabitPause(start: calendar.startOfDay(for: date($0.0)), end: calendar.startOfDay(for: date($0.1))) }
        let habit = Habit(
            createdAt: date(created),
            scheduleKind: kind,
            scheduleDaysMask: mask,
            weeklyTarget: weeklyTarget,
            logs: logs,
            pauses: pauses
        )
        logs.forEach { $0.habit = habit }
        pauses.forEach { $0.habit = habit }
        return habit
    }

    // MARK: - Week goal

    @Test func dailyHabitsGetOneRestDay() {
        let sixOfSeven = habit(doneOn: [6, 7, 8, 9, 10, 11]).weekGoal(containing: date(8), calendar: calendar)
        #expect(sixOfSeven == WeekGoal(completed: 6, required: 6, restDays: 1))
        #expect(sixOfSeven.isMet)
        #expect(!habit(doneOn: [6, 7, 8, 9, 10]).weekGoal(containing: date(8), calendar: calendar).isMet)
    }

    @Test func weekdayHabitsNeedFourOfFive() {
        let weekdays = (2...6).reduce(0) { $0 | (1 << ($1 - 1)) }
        let goal = habit(.specificWeekdays, mask: weekdays, doneOn: [6, 7, 8, 9]).weekGoal(containing: date(8), calendar: calendar)
        #expect(goal == WeekGoal(completed: 4, required: 4, restDays: 1))
        #expect(goal.isMet)
    }

    @Test func fewerThanFiveDueDaysNeedAllOfThem() {
        let monWedFri = (1 << 1) | (1 << 3) | (1 << 5)
        let goal = habit(.specificWeekdays, mask: monWedFri, doneOn: [6, 8]).weekGoal(containing: date(8), calendar: calendar)
        #expect(goal == WeekGoal(completed: 2, required: 3, restDays: 0))
        #expect(!goal.isMet)
    }

    @Test func timesPerWeekUsesTheTarget() {
        let goal = habit(.timesPerWeek, weeklyTarget: 3, doneOn: [5, 6, 7]).weekGoal(containing: date(8), calendar: calendar)
        #expect(goal == WeekGoal(completed: 2, required: 3, restDays: 0))
    }

    @Test func creationWeekOnlyCountsDaysSinceCreation() {
        // Created Friday the 10th: Fri, Sat, Sun are due, so all three are needed.
        let goal = habit(createdOn: 10, doneOn: [10, 11]).weekGoal(containing: date(10), calendar: calendar)
        #expect(goal == WeekGoal(completed: 2, required: 3, restDays: 0))
    }

    @Test func pausedDaysAreNotDueAndScaleTimesPerWeek() {
        // Paused Mon–Thu: daily needs Fri–Sun; 3× a week needs ceil(3 × 3/7) = 2.
        let daily = habit(doneOn: [10, 11, 12], paused: [(6, 9)])
        #expect(daily.weekGoal(containing: date(8), calendar: calendar) == WeekGoal(completed: 3, required: 3, restDays: 0))
        #expect(!daily.isDue(on: date(7), calendar: calendar))
        let weekly = habit(.timesPerWeek, weeklyTarget: 3, doneOn: [11, 12], paused: [(6, 9)])
        #expect(weekly.weekGoal(containing: date(8), calendar: calendar).isMet)
    }

    @Test func fullyPausedWeekIsNeutral() {
        let goal = habit(doneOn: [], paused: [(6, 12)]).weekGoal(containing: date(8), calendar: calendar)
        #expect(goal.isNeutral)
        #expect(!goal.isMet)
    }

    // MARK: - Weekly streak

    @Test func streakCountsMetWeeksAndAnUnfinishedWeekDoesNotBreakIt() {
        // Weeks of the 6th and 13th met; on Tue the 21st the current week is in progress.
        let days = Array(6...11) + Array(13...18) + [20]
        let streak = habit(doneOn: days).weeklyStreak(today: date(21), calendar: calendar)
        #expect(streak == WeeklyStreak(current: 2, best: 2))
    }

    @Test func currentWeekCountsOnceMet() {
        let days = Array(6...11) + Array(13...18)
        #expect(habit(doneOn: days).weeklyStreak(today: date(19), calendar: calendar).current == 2)
        #expect(habit(doneOn: Array(6...11) + Array(13...17)).weeklyStreak(today: date(17), calendar: calendar).current == 1)
    }

    @Test func missedWeekResetsTheStreakButKeepsBest() {
        // Met the weeks of the 6th and 13th, missed the 20th; Mon–Fri of the 27th done so far.
        let days = Array(6...11) + Array(13...18) + [20] + Array(27...31)
        let streak = habit(doneOn: days).weeklyStreak(today: date(31), calendar: calendar)
        #expect(streak.best == 2)
        #expect(streak.current == 0)
    }

    @Test func pausedWeekKeepsTheStreak() {
        // Met the week of the 6th, paused the week of the 13th (added afterwards), met the 20th.
        let days = Array(6...11) + Array(20...25)
        let streak = habit(doneOn: days, paused: [(13, 19)]).weeklyStreak(today: date(26), calendar: calendar)
        #expect(streak == WeeklyStreak(current: 2, best: 2))
    }

    @Test func weeksFollowTheCalendarsFirstWeekday() {
        var sundayFirst = calendar
        sundayFirst.firstWeekday = 1
        // Sun 5th – Sat 11th is one week; Mon–Sat done is 6 of 7.
        let goal = habit(createdOn: 5, doneOn: [6, 7, 8, 9, 10, 11]).weekGoal(containing: date(8), calendar: sundayFirst)
        #expect(goal == WeekGoal(completed: 6, required: 6, restDays: 1))
    }

    // MARK: - Other stats

    @Test func lifetimeStatsCountCompletedDays() {
        let stats = HabitStats(habit: habit(doneOn: [20, 21, 22]), today: date(22), calendar: calendar)
        #expect(stats.totalCompleted == 3)
        #expect(stats.last30Percent == 10)
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
