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
