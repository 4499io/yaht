import SwiftUI
import SwiftData
import UserNotifications
import OSLog

@main
struct YahtApp: App {
    // Skip full app startup under XCTest so unit tests don't boot the UI or
    // instantiate the persistent ModelContainer / services. Keeps the test
    // target lightweight and deterministic (the host app must not crash).
    private let isRunningTests: Bool = YahtApp.detectTests()

    private enum StartupState {
        case ready(ModelContainer, HabitStore?)
        case failed
    }

    @State private var startup: StartupState

    init() {
        _startup = State(initialValue: YahtApp.loadStartup(runningTests: YahtApp.detectTests()))
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            switch startup {
            case let .ready(container, store):
                Group {
                    if isRunningTests {
                        Color.clear
                    } else if let store {
                        ContentView()
                            .environment(store)
                            .task {
                                _ = await NotificationScheduler.shared.requestAuthorization()
                            }
                    }
                }
                .modelContainer(container)
            case .failed:
                ContentUnavailableView {
                    Label("Unable to Open Habits", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your saved data has been kept. Try opening it again. If the problem continues, contact support before changing or removing app data.")
                } actions: {
                    Button("Retry") {
                        startup = YahtApp.loadStartup(runningTests: isRunningTests)
                    }
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("store-startup-retry")
                }
                .accessibilityIdentifier("store-startup-error")
                .phoneWidthConstrained()
            }
        }
    }
}

private extension YahtApp {
    static func detectTests() -> Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestBundlePath"] != nil || env["XCTestSessionIdentifier"] != nil
    }

    static func loadStartup(runningTests: Bool) -> StartupState {
        do {
            let container = try runningTests
                ? PersistentStoreLoader.makeTestContainer()
                : PersistentStoreLoader.makePersistentContainer()
            return .ready(container, runningTests ? nil : HabitStore(modelContext: container.mainContext))
        } catch {
            let logger = Logger(subsystem: "io.yaht.Yaht", category: "persistence")
            // Keep model/error details private; the UI never exposes database paths.
            logger.error("Persistent store startup failed: \(String(describing: error), privacy: .private)")
            return .failed
        }
    }
}

// MARK: - Notification presentation

/// Presents notifications while the app is foregrounded. Singleton set as the
/// UNUserNotificationCenter delegate at launch.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()

    private override init() { super.init() }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
