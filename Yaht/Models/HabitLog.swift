import Foundation
import SwiftData

/// A single day's completion record for a habit. `day` is normalized to the
/// start of day; `count` is the tally (>=1 means "done" for binary habits).
@Model
final class HabitLog {
    var id: UUID = UUID()
    var day: Date = Date()
    var count: Int = 1
    var updatedAt: Date = Date()
    var habit: Habit?

    init(
        id: UUID = UUID(),
        day: Date = Date(),
        count: Int = 1,
        updatedAt: Date = Date(),
        habit: Habit? = nil
    ) {
        self.id = id
        self.day = day
        self.count = count
        self.updatedAt = updatedAt
        self.habit = habit
    }
}
