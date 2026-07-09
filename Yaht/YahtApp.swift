import SwiftUI
import SwiftData
import UserNotifications

@main
struct YahtApp: App {
    // Skip full app startup under XCTest so unit tests don't boot the UI or
    // instantiate the persistent ModelContainer / services. Keeps the test
    // target lightweight and deterministic (the host app must not crash).
    private let isRunningTests: Bool = YahtApp.detectTests()

    @State private var container: ModelContainer
    @State private var store: HabitStore?

    init() {
        let runningTests = YahtApp.detectTests()
        // Under tests, use a throwaway in-memory container purely to satisfy
        // `.modelContainer(_:)` — never touch the on-disk store or services.
        let container = runningTests
            ? YahtApp.makeInMemoryContainer()
            : YahtApp.makePersistentContainer()
        _container = State(initialValue: container)
        _store = State(initialValue: runningTests
            ? nil
            : HabitStore(modelContext: container.mainContext))

        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isRunningTests {
                    Color.clear
                } else if let store {
                    ContentView()
                        .environment(store)
                        .task {
                            // Fire-and-forget: ask for notification permission.
                            _ = await NotificationScheduler.shared.requestAuthorization()
                        }
                } else {
                    Color.clear
                }
            }
            .modelContainer(container)
        }
    }
}

// MARK: - Container construction

private extension YahtApp {
    static func detectTests() -> Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestBundlePath"] != nil || env["XCTestSessionIdentifier"] != nil
    }

    /// URL of the on-disk SQLite store inside Application Support.
    static func storeURL() -> URL {
        let fileManager = FileManager.default
        let base = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("Yaht.sqlite")
    }

    /// Builds the local persistent container, recovering from a corrupt store.
    static func makePersistentContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let url = storeURL()
        // TODO(cloudkit): switch ModelConfiguration to cloudKitDatabase:.automatic
        // once the io.4499.yaht App ID has iCloud+CloudKit enabled.
        let configuration = ModelConfiguration(schema: schema, url: url)

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: AppMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            // Do NOT delete: move the (likely corrupt) store aside and retry
            // with a fresh one so the user keeps a chance at recovery.
            moveStoreAside(url)
            do {
                return try ModelContainer(
                    for: schema,
                    migrationPlan: AppMigrationPlan.self,
                    configurations: [configuration]
                )
            } catch {
                // Last resort: run entirely in memory this session.
                return makeInMemoryContainer()
            }
        }
    }

    /// In-memory container used for tests and as the final fallback.
    static func makeInMemoryContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Yaht: unable to create in-memory ModelContainer: \(error)")
        }
    }

    /// Renames the store (and its -wal/-shm sidecars) aside so a fresh one can
    /// be created. Suffix avoids Date() so it stays deterministic per launch.
    static func moveStoreAside(_ url: URL) {
        let fileManager = FileManager.default
        let suffix = ".corrupt-\(Int(ProcessInfo.processInfo.systemUptime))"
        let paths = [url.path, url.path + "-wal", url.path + "-shm"]
        for path in paths where fileManager.fileExists(atPath: path) {
            do {
                try fileManager.moveItem(atPath: path, toPath: path + suffix)
            } catch {
                // Best-effort recovery; ignore individual move failures.
            }
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
