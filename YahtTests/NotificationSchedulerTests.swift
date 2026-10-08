import Foundation
import Testing
@testable import Yaht

/// Exercises the pure identifier/scope-fanout helpers, which carry no
/// `UNUserNotificationCenter` dependency and thus need no entitlements.
struct NotificationSchedulerTests {

    // MARK: Scope fan-out

    @Test func everyDayProducesSingleDailyTrigger() {
        let weekdays = NotificationScheduler.weekdays(for: .everyDay)
        #expect(weekdays == [nil])
    }

    @Test func weekdaysOnlyProducesFiveTriggers() {
        let weekdays = NotificationScheduler.weekdays(for: .weekdaysOnly)
        #expect(weekdays.count == 5)
        #expect(weekdays == [2, 3, 4, 5, 6])
    }

    @Test func weekendsOnlyProducesTwoTriggers() {
        let weekdays = NotificationScheduler.weekdays(for: .weekendsOnly)
        #expect(weekdays.count == 2)
        #expect(weekdays == [1, 7])
    }

    @Test func someDaysHabitsUseTheirDaysWhateverTheReminderScope() {
        #expect(NotificationScheduler.reminderWeekdays(scope: .everyDay, habitWeekdays: [5]) == [5])
        #expect(NotificationScheduler.reminderWeekdays(scope: .weekendsOnly, habitWeekdays: [6, 2]) == [2, 6])
        #expect(NotificationScheduler.reminderWeekdays(scope: .everyDay, habitWeekdays: []).isEmpty)
    }

    @Test func otherHabitsFollowTheReminderScope() {
        #expect(NotificationScheduler.reminderWeekdays(scope: .everyDay, habitWeekdays: nil) == [nil])
        #expect(NotificationScheduler.reminderWeekdays(scope: .weekendsOnly, habitWeekdays: nil) == [1, 7])
    }

    // MARK: Hourly nudges

    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        if let zone = TimeZone(identifier: "UTC") { cal.timeZone = zone }
        return cal
    }

    /// January 2025 at the given hour; the 9th is a Thursday (weekday 5).
    private func jan(_ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        utc.date(from: DateComponents(year: 2025, month: 1, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    @Test func nudgesFireHourlyAfterTheReminderUntilTheLastHour() {
        let dates = NotificationScheduler.nudgeDates(
            hour: 19, minute: 30, weekdays: [nil], days: [jan(9)], now: jan(9, 8), calendar: utc
        )
        #expect(dates == [jan(9, 20, 30), jan(9, 21, 30), jan(9, 22, 30)])
    }

    @Test func nudgesSkipPastTimesAndOtherWeekdays() {
        // Now 20:45 on Thursday; Friday the 10th is not a reminder day.
        let dates = NotificationScheduler.nudgeDates(
            hour: 19, minute: 0, weekdays: [5], days: [jan(9), jan(10)], now: jan(9, 20, 45), calendar: utc
        )
        #expect(dates == [jan(9, 21), jan(9, 22)])
    }

    @Test func lateRemindersHaveNoNudges() {
        let dates = NotificationScheduler.nudgeDates(
            hour: 22, minute: 0, weekdays: [nil], days: [jan(9)], now: jan(9), calendar: utc
        )
        #expect(dates.isEmpty)
    }

    @Test func nudgeIdentifierStaysInTheHabitNamespace() throws {
        let habitID = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let reminderID = try #require(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let id = NotificationScheduler.nudgeIdentifier(
            habitID: habitID, reminderID: reminderID, date: jan(9, 20, 30), calendar: utc
        )
        #expect(id.hasPrefix(NotificationScheduler.identifierPrefix(forHabitID: habitID)))
        #expect(id.hasSuffix("-nudge-202501092030"))
    }

    @MainActor
    @Test func checkingOffTodayDropsTodaysNudgeDay() {
        let habit = Habit(name: "Gym", createdAt: jan(1))
        habit.reminders = [Reminder(hour: 9, minute: 0, repeatsHourly: true, habit: habit)]
        let open = NotificationHabitSnapshot(habit, now: jan(9, 10), calendar: utc)
        #expect(open.nudgeDays == [jan(9), jan(10)])

        let log = HabitLog(day: jan(9), count: 1)
        log.habit = habit
        habit.logs = [log]
        let done = NotificationHabitSnapshot(habit, now: jan(9, 10), calendar: utc)
        #expect(done.nudgeDays == [jan(10)])
    }

    @MainActor
    @Test func remindersWithoutHourlyRepeatHaveNoNudgeDays() {
        let habit = Habit(name: "Read", createdAt: jan(1))
        habit.reminders = [Reminder(hour: 9, minute: 0, habit: habit)]
        #expect(NotificationHabitSnapshot(habit, now: jan(9, 10), calendar: utc).nudgeDays.isEmpty)
    }

    // MARK: Identifier format

    @Test func identifierEncodesWeekday() throws {
        let habitID = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let reminderID = try #require(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))

        let id = NotificationScheduler.identifier(
            habitID: habitID,
            reminderID: reminderID,
            weekday: 2
        )
        #expect(id == "habit-11111111-1111-1111-1111-111111111111-22222222-2222-2222-2222-222222222222-2")
    }

    @Test func identifierEncodesDailyWhenWeekdayIsNil() throws {
        let habitID = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let reminderID = try #require(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))

        let id = NotificationScheduler.identifier(
            habitID: habitID,
            reminderID: reminderID,
            weekday: nil
        )
        #expect(id.hasSuffix("-daily"))
        #expect(id == "habit-11111111-1111-1111-1111-111111111111-22222222-2222-2222-2222-222222222222-daily")
    }

    @Test func identifierIsPrefixedByHabitScopedPrefix() throws {
        let habitID = try #require(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let reminderID = try #require(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))

        let prefix = NotificationScheduler.identifierPrefix(forHabitID: habitID)
        let id = NotificationScheduler.identifier(
            habitID: habitID,
            reminderID: reminderID,
            weekday: 7
        )

        #expect(prefix == "habit-33333333-3333-3333-3333-333333333333-")
        #expect(id.hasPrefix(prefix))
    }

    // MARK: Budget

    @Test func pendingBudgetStaysUnderSystemLimit() {
        #expect(NotificationScheduler.pendingBudget <= 64)
    }
}
