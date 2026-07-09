import Testing
import Foundation
import SwiftUI
@testable import Yaht

/// Pure-logic tests for `Habit+Logic` — no persistence needed, models are built
/// in memory. Uses a fixed Gregorian/UTC calendar so weekday and interval
/// boundaries are deterministic regardless of the host locale/time zone.
@MainActor
struct HabitLogicTests {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        if let utc = TimeZone(identifier: "UTC") { cal.timeZone = utc }
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let comps = DateComponents(year: year, month: month, day: day, hour: 12)
        guard let d = calendar.date(from: comps) else { return .distantPast }
        return d
    }

    // MARK: - isDue

    @Test func dailyIsAlwaysDue() {
        let habit = Habit(scheduleKind: .daily)
        #expect(habit.isDue(on: date(2025, 1, 6), calendar: calendar))
        #expect(habit.isDue(on: date(2025, 1, 7), calendar: calendar))
    }

    @Test func specificWeekdaysRespectsMask() {
        // Monday (weekday 2 => bit1 = 2) and Wednesday (weekday 4 => bit3 = 8).
        let mask = (1 << 1) | (1 << 3)
        let habit = Habit(scheduleKind: .specificWeekdays, scheduleDaysMask: mask)

        #expect(habit.isDue(on: date(2025, 1, 6), calendar: calendar))  // Monday
        #expect(!habit.isDue(on: date(2025, 1, 7), calendar: calendar)) // Tuesday
        #expect(habit.isDue(on: date(2025, 1, 8), calendar: calendar))  // Wednesday
        #expect(!habit.isDue(on: date(2025, 1, 5), calendar: calendar)) // Sunday
    }

    @Test func everyNDaysHitsBoundaries() {
        let created = date(2025, 1, 1)
        let habit = Habit(createdAt: created, scheduleKind: .everyNDays, intervalDays: 3)

        #expect(habit.isDue(on: date(2025, 1, 1), calendar: calendar))  // day 0
        #expect(!habit.isDue(on: date(2025, 1, 2), calendar: calendar)) // day 1
        #expect(!habit.isDue(on: date(2025, 1, 3), calendar: calendar)) // day 2
        #expect(habit.isDue(on: date(2025, 1, 4), calendar: calendar))  // day 3
        #expect(habit.isDue(on: date(2025, 1, 7), calendar: calendar))  // day 6
        #expect(!habit.isDue(on: date(2024, 12, 31), calendar: calendar)) // before creation
    }

    @Test func timesPerWeekDueUntilTargetMet() {
        let habitNoTarget = Habit(scheduleKind: .timesPerWeek, weeklyTarget: 0)
        #expect(!habitNoTarget.isDue(on: date(2025, 1, 6), calendar: calendar))

        // Target 2, one completed day this week -> still due.
        let log = HabitLog(day: date(2025, 1, 6), count: 1)
        let habit = Habit(scheduleKind: .timesPerWeek, weeklyTarget: 2, logs: [log])
        log.habit = habit
        #expect(habit.isDue(on: date(2025, 1, 7), calendar: calendar))

        // Two completed days -> target met -> not due.
        let logA = HabitLog(day: date(2025, 1, 6), count: 1)
        let logB = HabitLog(day: date(2025, 1, 7), count: 1)
        let met = Habit(scheduleKind: .timesPerWeek, weeklyTarget: 2, logs: [logA, logB])
        logA.habit = met
        logB.habit = met
        #expect(!met.isDue(on: date(2025, 1, 8), calendar: calendar))
    }

    // MARK: - isCompleted / progress (both kinds)

    @Test func binaryCompletionAndProgress() {
        let day = date(2025, 1, 6)
        let empty = Habit(kind: .binary)
        #expect(!empty.isCompleted(on: day, calendar: calendar))
        #expect(empty.progress(on: day, calendar: calendar) == 0)

        let log = HabitLog(day: day, count: 1)
        let done = Habit(kind: .binary, logs: [log])
        log.habit = done
        #expect(done.isCompleted(on: day, calendar: calendar))
        #expect(done.progress(on: day, calendar: calendar) == 1)
        #expect(done.dayCount(on: day, calendar: calendar) == 1)
    }

    @Test func countCompletionAndProgress() {
        let day = date(2025, 1, 6)
        let partialLog = HabitLog(day: day, count: 2)
        let habit = Habit(kind: .count, dailyTarget: 3, logs: [partialLog])
        partialLog.habit = habit

        #expect(!habit.isCompleted(on: day, calendar: calendar))
        #expect(abs(habit.progress(on: day, calendar: calendar) - (2.0 / 3.0)) < 1e-9)

        partialLog.count = 3
        #expect(habit.isCompleted(on: day, calendar: calendar))
        #expect(habit.progress(on: day, calendar: calendar) == 1)

        // Over target clamps to 1.
        partialLog.count = 10
        #expect(habit.isCompleted(on: day, calendar: calendar))
        #expect(habit.progress(on: day, calendar: calendar) == 1)
    }

    // MARK: - Color

    @Test func colorParsing() {
        #expect(Color(hex: "FF0000") != nil)
        #expect(Color(hex: "#5FB8C4") != nil)
        #expect(Color(hex: "not-a-color") == nil)

        let good = Habit(colorHex: "5FB8C4")
        // Resolvable hex round-trips to a non-nil hex string via the color.
        #expect(good.color.toHex() != nil)
    }
}
