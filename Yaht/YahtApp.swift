import SwiftUI

@main
struct YahtApp: App {
    // Skip full app startup under XCTest so unit tests don't boot the UI or
    // (later) instantiate the ModelContainer / services. Copied from the
    // 99issues pattern — keeps the test target lightweight and deterministic.
    private let isRunningTests: Bool = {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestBundlePath"] != nil || env["XCTestSessionIdentifier"] != nil
    }()

    var body: some Scene {
        WindowGroup {
            if isRunningTests {
                Color.clear
            } else {
                ContentView()
            }
        }
    }
}
