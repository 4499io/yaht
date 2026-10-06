import Foundation
import SwiftData

/// Opens the existing store without renaming, deleting, or replacing its files.
/// CloudKit failures do not establish corruption; local persistence gets a
/// second attempt at the same URL before startup reports an error.
@MainActor
enum PersistentStoreLoader {
    enum Mode: Equatable {
        case cloud
        case local
    }

    struct Failure: Error {
        let cloudError: any Error
        let localError: any Error
    }

    /// Injectable construction keeps fallback policy independent of SwiftData
    /// and lets tests exercise failures without touching a real CloudKit store.
    static func load<Value>(
        at url: URL,
        build: (URL, Mode) throws -> Value
    ) throws -> Value {
        do {
            return try build(url, .cloud)
        } catch {
            let cloudError = error
            do {
                return try build(url, .local)
            } catch {
                throw Failure(cloudError: cloudError, localError: error)
            }
        }
    }

    static func makePersistentContainer() throws -> ModelContainer {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let url = base.appendingPathComponent("Yaht.sqlite")
        let schema = Schema(versionedSchema: SchemaV1.self)
        return try load(at: url) { storeURL, mode in
            let configuration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: mode == .cloud ? .automatic : .none
            )
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        }
    }

    /// Tests alone use a throwaway store. Failed production startup never
    /// creates a writable in-memory session that could silently lose entries.
    static func makeTestContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
