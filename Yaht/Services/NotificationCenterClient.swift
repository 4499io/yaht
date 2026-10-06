import UserNotifications

/// MainActor seam avoids passing notification-center objects between actors.
@MainActor
protocol NotificationCenterClient {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func pendingRequests() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func waitUntilRemoved(_ identifiers: Set<String>) async -> Bool
    /// Returns true only after the IDs are observed absent. On false, callers
    /// must defer reuse and recheck readiness without issuing another removal.
    func removePendingRequests(withIdentifiers identifiers: [String]) async -> Bool
}

@MainActor
final class SystemNotificationCenterClient: NotificationCenterClient {
    private let center = UNUserNotificationCenter.current()

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func pendingRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) async -> Bool {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        return await waitUntilRemoved(Set(identifiers))
    }
}

@MainActor
extension NotificationCenterClient {
    /// The system removal call queues work and has no completion callback.
    /// Observe readiness instead of assuming a delay is long enough. Finish this
    /// bounded barrier even if the caller is cancelled after removal began.
    func waitUntilRemoved(_ identifiers: Set<String>) async -> Bool {
        guard !identifiers.isEmpty else { return true }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        repeat {
            let pending = await pendingRequests()
            if pending.allSatisfy({ !identifiers.contains($0.identifier) }) { return true }
            // Pace the polls; a cancelled caller still finishes the barrier.
            do { try await Task.sleep(for: .milliseconds(50)) } catch { await Task.yield() }
        } while clock.now < deadline
        return false
    }
}
