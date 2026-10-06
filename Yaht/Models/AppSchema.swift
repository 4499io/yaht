import Foundation
import SwiftData

/// The persisted SwiftData schema. The app is unreleased, so there are no
/// versioned migrations yet; keep changes additive (optional properties and
/// relationships, new entities) so CloudKit and existing test installs follow.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Habit.self, Reminder.self, HabitLog.self, HabitPause.self]
    }
}
