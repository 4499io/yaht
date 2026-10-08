import Foundation
import Testing
@testable import Yaht

@MainActor
struct CalendarDayStatusTests {
    private let today = Date(timeIntervalSince1970: 1_700_000_000)
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func futureAndPreCreationDaysAreNotFailures() {
        let habit = Habit(createdAt: today)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        #expect(CalendarDayStatus(habit: habit, date: tomorrow, today: today, calendar: calendar) == .future)
        #expect(CalendarDayStatus(habit: habit, date: yesterday, today: today, calendar: calendar) == .beforeStart)
    }

    @Test func pausedAndUnscheduledDaysHaveTheirOwnStates() {
        let pause = HabitPause(start: today, end: today)
        let paused = Habit(createdAt: today, pauses: [pause])
        let unscheduled = Habit(createdAt: today, scheduleKind: .specificWeekdays, scheduleDaysMask: 0)
        #expect(CalendarDayStatus(habit: paused, date: today, today: today, calendar: calendar) == .paused)
        #expect(CalendarDayStatus(habit: unscheduled, date: today, today: today, calendar: calendar) == .notScheduled)
    }

    @Test func countHistoryDistinguishesPartialAndReachedGoals() {
        let habit = Habit(createdAt: today, kind: .count, dailyTarget: 8)
        let log = HabitLog(day: today, count: 3)
        habit.logs = [log]
        #expect(CalendarDayStatus(habit: habit, date: today, today: today, calendar: calendar) == .partial)
        log.count = 8
        #expect(CalendarDayStatus(habit: habit, date: today, today: today, calendar: calendar) == .done)
        log.count = 0
        #expect(CalendarDayStatus(habit: habit, date: today, today: today, calendar: calendar) == .notDone)
    }
}
