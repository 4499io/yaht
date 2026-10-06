import Foundation
import SwiftData

/// A stretch of days a habit is paused, e.g. for illness or a holiday. Paused
/// days are not due: they neither count toward nor break a streak, and the
/// habit's reminders are held back. `start` and `end` are local start-of-day
/// dates and both are included.
@Model
final class HabitPause {
    var id: UUID = UUID()
    var start: Date = Date()
    var end: Date = Date()
    var createdAt: Date = Date()
    var habit: Habit?

    init(id: UUID = UUID(), start: Date, end: Date, createdAt: Date = Date(), habit: Habit? = nil) {
        self.id = id
        self.start = start
        self.end = end
        self.createdAt = createdAt
        self.habit = habit
    }

    /// Whether `day` falls inside this pause.
    func contains(_ day: Date, calendar: Calendar = .current) -> Bool {
        let start = calendar.startOfDay(for: self.start)
        let end = calendar.startOfDay(for: self.end)
        let day = calendar.startOfDay(for: day)
        return day >= start && day <= end
    }
}
