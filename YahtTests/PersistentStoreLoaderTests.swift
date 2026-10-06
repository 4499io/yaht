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
