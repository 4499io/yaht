import Foundation
import SwiftData
import Testing
@testable import Yaht

@MainActor
struct PersistentStoreLoaderTests {
    private enum StubError: Error, Equatable {
        case cloudUnavailable
        case localUnavailable
    }

    @Test func cloudSuccessDoesNotAttemptLocalFallback() throws {
        let url = URL(fileURLWithPath: "/unused/Yaht.sqlite")
        var attempts: [PersistentStoreLoader.Mode] = []
        let value = try PersistentStoreLoader.load(at: url) { attemptedURL, mode in
            #expect(attemptedURL == url)
            attempts.append(mode)
            return "opened"
        }
        #expect(value == "opened")
        #expect(attempts == [.cloud])
    }

    @Test func cloudFailureRetriesLocalAtOriginalURLWithoutMovingFiles() throws {
        try withStoreFiles { url, originalFiles in
            var attempts: [PersistentStoreLoader.Mode] = []
            let value = try PersistentStoreLoader.load(at: url) { attemptedURL, mode in
                #expect(attemptedURL == url)
                attempts.append(mode)
                if mode == .cloud { throw StubError.cloudUnavailable }
                return "local"
            }
            #expect(value == "local")
            #expect(attempts == [.cloud, .local])
            try expectUnchangedFiles(at: url, originalFiles: originalFiles)
        }
    }

    @Test func doubleFailurePreservesFilesAndSurfacesBothErrors() throws {
        try withStoreFiles { url, originalFiles in
            var attempts: [PersistentStoreLoader.Mode] = []
            var failure: PersistentStoreLoader.Failure?
            do {
                let _: String = try PersistentStoreLoader.load(at: url) { attemptedURL, mode in
                    #expect(attemptedURL == url)
                    attempts.append(mode)
                    throw mode == .cloud ? StubError.cloudUnavailable : StubError.localUnavailable
                }
                Issue.record("Startup must fail instead of returning a volatile store")
            } catch let error as PersistentStoreLoader.Failure {
                failure = error
            }
            let error = try #require(failure)
            #expect(error.cloudError as? StubError == .cloudUnavailable)
            #expect(error.localError as? StubError == .localUnavailable)
            #expect(attempts == [.cloud, .local])
            try expectUnchangedFiles(at: url, originalFiles: originalFiles)
        }
    }

    @Test func testContainersAreIndependentAndVolatile() throws {
        let first = try PersistentStoreLoader.makeTestContainer()
        first.mainContext.insert(Habit(name: "Test habit"))
        try first.mainContext.save()
        #expect(try first.mainContext.fetchCount(FetchDescriptor<Habit>()) == 1)
        let second = try PersistentStoreLoader.makeTestContainer()
        #expect(try second.mainContext.fetchCount(FetchDescriptor<Habit>()) == 0)
    }

    /// Exercises an actual local SQLite store. The cloud attempt is deliberately
    /// stubbed; compatibility with a CloudKit-backed store needs device testing.
    @Test func localFallbackReopensExistingHabitsAndLogs() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                Issue.record("Could not clean up the temporary SwiftData store: \(error)")
            }
        }
        let url = directory.appendingPathComponent("Yaht.sqlite")
        let habitID = UUID()
        let logID = UUID()
        let day = Date(timeIntervalSince1970: 1_700_000_000)

        // Separate scopes and autorelease pools release the original container,
        // context, and models before reopening and before deleting the directory.
        try autoreleasepool {
            try seedLocalStore(at: url, habitID: habitID, logID: logID, day: day)
        }
        #expect(FileManager.default.fileExists(atPath: url.path))
        try autoreleasepool {
            try verifyLocalFallback(at: url, habitID: habitID, logID: logID, day: day)
        }
    }

    private func makeLocalContainer(at url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: CurrentSchema.self)
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(
            for: schema,
            migrationPlan: AppMigrationPlan.self,
            configurations: [configuration]
        )
    }

    private func seedLocalStore(at url: URL, habitID: UUID, logID: UUID, day: Date) throws {
        let container = try makeLocalContainer(at: url)
        let habit = Habit(id: habitID, name: "Drink water", kind: .count, dailyTarget: 5, unit: "glasses")
        let log = HabitLog(id: logID, day: day, count: 3, updatedAt: day, habit: habit)
        container.mainContext.insert(habit)
        container.mainContext.insert(log)
        try container.mainContext.save()
    }

    private func verifyLocalFallback(at url: URL, habitID: UUID, logID: UUID, day: Date) throws {
        var attempts: [PersistentStoreLoader.Mode] = []
        let container = try PersistentStoreLoader.load(at: url) { attemptedURL, mode in
            #expect(attemptedURL == url)
            attempts.append(mode)
            if mode == .cloud { throw StubError.cloudUnavailable }
            return try makeLocalContainer(at: attemptedURL)
        }
        #expect(attempts == [.cloud, .local])
        let habits = try container.mainContext.fetch(FetchDescriptor<Habit>())
        let logs = try container.mainContext.fetch(FetchDescriptor<HabitLog>())
        #expect(habits.count == 1)
        #expect(logs.count == 1)
        let habit = try #require(habits.first)
        let log = try #require(logs.first)
        #expect(habit.id == habitID)
        #expect(habit.name == "Drink water")
        #expect(habit.habitKind == .count)
        #expect(habit.dailyTarget == 5)
        #expect(habit.unit == "glasses")
        #expect(log.id == logID)
        #expect(log.day == day)
        #expect(log.updatedAt == day)
        #expect(log.count == 3)
        #expect(log.habit?.id == habitID)
        #expect(habit.logs?.map(\.id) == [logID])
        #expect(habit.dayCount(on: day) == 3)
    }

    private func withStoreFiles(
        _ body: (URL, [String: Data]) throws -> Void
    ) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Yaht.sqlite")
        let files = [
            "Yaht.sqlite": Data("existing database".utf8),
            "Yaht.sqlite-wal": Data("existing write-ahead log".utf8),
            "Yaht.sqlite-shm": Data("existing shared memory".utf8)
        ]
        for (name, data) in files {
            try data.write(to: directory.appendingPathComponent(name))
        }
        try body(url, files)
    }

    private func expectUnchangedFiles(at url: URL, originalFiles: [String: Data]) throws {
        let directory = url.deletingLastPathComponent()
        let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(Set(remaining) == Set(originalFiles.keys))
        for (name, data) in originalFiles {
            #expect(try Data(contentsOf: directory.appendingPathComponent(name)) == data)
        }
    }
}
