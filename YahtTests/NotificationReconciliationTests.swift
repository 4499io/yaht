import Foundation
import Testing
import UserNotifications
@testable import Yaht

@MainActor
struct NotificationReconciliationTests {
    @Test func importedRemindersAreScheduledAndDeletedDisabledArchivedOnesAreRemoved() async {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(center: center)
        let imported = makeHabit(name: "Imported", count: 2)
        let unrelated = request(id: "unrelated-request")
        center.requests[unrelated.identifier] = unrelated

        await scheduler.rescheduleAll([imported])
        #expect(center.requests.count == 3)
        #expect(center.requests.values.filter { $0.content.title.contains("Imported") }.count == 2)

        imported.reminders?.first?.isEnabled = false
        await scheduler.rescheduleAll([imported])
        #expect(center.requests.count == 2)
        imported.isArchived = true
        await scheduler.rescheduleAll([imported])
        #expect(Set(center.requests.keys) == ["unrelated-request"])

        imported.isArchived = false
        await scheduler.rescheduleAll([imported])
        #expect(center.requests.count == 2)
        await scheduler.rescheduleAll([])
        #expect(Set(center.requests.keys) == ["unrelated-request"])
    }

    @Test func deniedAuthorizationRemovesStaleRemindersAndRetainsOtherRequests() async {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(center: center)
        let habit = makeHabit(name: "Read", count: 1)
        await scheduler.rescheduleAll([habit])
        center.requests["other"] = request(id: "other")
        center.status = .denied
        #expect(await scheduler.requestAuthorization() == false)
        await scheduler.rescheduleAll([habit])
        #expect(Set(center.requests.keys) == ["other"])
        #expect(center.authorizationOptions.isEmpty)
    }

    @Test func permissionRequestUsesOnlyAlertSoundAndBadgeAndThenSchedules() async {
        let center = FakeNotificationCenter()
        center.status = .notDetermined
        let scheduler = NotificationScheduler(center: center)
        #expect(await scheduler.requestAuthorization())
        #expect(center.authorizationOptions == [.alert, .sound, .badge])
        await scheduler.rescheduleAll([makeHabit(name: "Read", count: 1)])
        #expect(center.requests.count == 1)
        #expect(await scheduler.requestAuthorization())
        #expect(center.authorizationRequestCount == 1)
    }

    @Test func globalBudgetAccountsForRequestsOutsideHabitNamespace() async {
        let center = FakeNotificationCenter()
        for index in 0..<7 { center.requests["other-\(index)"] = request(id: "other-\(index)") }
        let scheduler = NotificationScheduler(center: center)
        await scheduler.rescheduleAll([makeHabit(name: "Read", count: 70)])
        #expect(center.requests.count == NotificationScheduler.pendingBudget)
        #expect(center.requests.keys.filter { $0.hasPrefix("other-") }.count == 7)
        #expect(center.peakPendingCount <= NotificationScheduler.pendingBudget)
    }

    @Test func retainedRequestsAtBudgetPreventNewHabitRequests() async {
        let center = FakeNotificationCenter()
        for index in 0..<60 { center.requests["other-\(index)"] = request(id: "other-\(index)") }
        let originalIDs = Set(center.requests.keys)
        let scheduler = NotificationScheduler(center: center)
        await scheduler.rescheduleAll([makeHabit(name: "Read", count: 1)])
        #expect(Set(center.requests.keys) == originalIDs)
        #expect(center.addAttempts == 0)
    }

    @Test func concurrentHabitUpdatesShareBudgetAcrossSuspensionPoints() async {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(center: center)
        let firstHabit = makeHabit(name: "First", count: 40)
        let secondHabit = makeHabit(name: "Second", count: 40)
        center.pauseNextPending = true
        let first = Task { await scheduler.reschedule(for: firstHabit) }
        await center.waitForPendingPause()
        let second = Task { await scheduler.reschedule(for: secondHabit) }
        await Task.yield()
        #expect(center.pendingReadCount == 1)
        center.resumePendingRead()
        await first.value
        await second.value
        #expect(center.requests.count == NotificationScheduler.pendingBudget)
        #expect(center.peakPendingCount <= NotificationScheduler.pendingBudget)
    }

    @Test func queuedCancellationCannotBeUndoneByAnEarlierSuspendedSchedule() async {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(center: center)
        let habit = makeHabit(name: "Read", count: 1)
        center.pauseNextPending = true
        let scheduling = Task { await scheduler.reschedule(for: habit) }
        await center.waitForPendingPause()
        let cancellation = Task { await scheduler.cancel(forHabitID: habit.id) }
        await Task.yield()
        #expect(center.pendingReadCount == 1)
        center.resumePendingRead()
        await scheduling.value
        await cancellation.value
        #expect(center.requests.isEmpty)
    }

    @Test func modelChangesWhileSuspendedDoNotChangeTheCapturedRequest() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(center: center)
        let habit = makeHabit(name: "Before", count: 1)
        let reminder = try #require(habit.reminders?.first)
        let reminderID = reminder.id
        center.pauseNextPending = true
        let scheduling = Task { await scheduler.reschedule(for: habit) }
        await center.waitForPendingPause()
        habit.name = "After"
        reminder.hour = 20
        reminder.isEnabled = false
        center.resumePendingRead()
        await scheduling.value
        let scheduled = try #require(center.requests.values.first)
        #expect(scheduled.content.title == "📚 Before")
        #expect(scheduled.identifier.contains(reminderID.uuidString))
        let trigger = try #require(scheduled.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.hour == 9)
        await scheduler.rescheduleAll([habit])
        #expect(center.requests.isEmpty)
    }

    @Test func failedAdditionDoesNotConsumeTheRemainingBudget() async {
        let center = FakeNotificationCenter()
        for index in 0..<59 { center.requests["other-\(index)"] = request(id: "other-\(index)") }
        center.failNextAdd = true
        let scheduler = NotificationScheduler(center: center)
        await scheduler.rescheduleAll([makeHabit(name: "Read", count: 2)])
        #expect(center.addAttempts == 2)
        #expect(center.requests.count == 60)
    }

    private func makeHabit(name: String, count: Int) -> Habit {
        let habit = Habit(name: name, emoji: "📚")
        habit.reminders = (0..<count).map { _ in Reminder(hour: 9, minute: 30, habit: habit) }
        return habit
    }

    private func request(id: String) -> UNNotificationRequest {
        UNNotificationRequest(identifier: id, content: UNMutableNotificationContent(), trigger: nil)
    }
}

@MainActor
private final class FakeNotificationCenter: NotificationCenterClient {
    enum Failure: Error { case addFailed }
    var status: UNAuthorizationStatus = .authorized
    var requests: [String: UNNotificationRequest] = [:]
    var authorizationOptions: UNAuthorizationOptions = []
    var authorizationRequestCount = 0
    var pendingReadCount = 0
    var addAttempts = 0
    var peakPendingCount = 0
    var pauseNextPending = false
    var failNextAdd = false
    private var isPaused = false
    private var pausedObservers: [CheckedContinuation<Void, Never>] = []
    private var pendingContinuation: CheckedContinuation<Void, Never>?

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationRequestCount += 1
        authorizationOptions = options
        status = .authorized
        return true
    }

    func pendingRequests() async -> [UNNotificationRequest] {
        pendingReadCount += 1
        if pauseNextPending {
            pauseNextPending = false
            await withCheckedContinuation { continuation in
                pendingContinuation = continuation
                isPaused = true
                for observer in pausedObservers { observer.resume() }
                pausedObservers.removeAll()
            }
            isPaused = false
        }
        await Task.yield()
        return requests.keys.sorted().compactMap { requests[$0] }
    }

    func waitForPendingPause() async {
        guard !isPaused else { return }
        await withCheckedContinuation { pausedObservers.append($0) }
    }

    func resumePendingRead() {
        pendingContinuation?.resume()
        pendingContinuation = nil
    }

    func add(_ request: UNNotificationRequest) async throws {
        addAttempts += 1
        await Task.yield()
        if failNextAdd {
            failNextAdd = false
            throw Failure.addFailed
        }
        requests[request.identifier] = request
        peakPendingCount = max(peakPendingCount, requests.count)
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        for id in identifiers { requests.removeValue(forKey: id) }
    }
}
