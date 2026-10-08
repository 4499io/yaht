import Foundation
import SwiftData

/// A scheduled local notification time attached to a habit.
@Model
final class Reminder {
    var id: UUID = UUID()
    var hour: Int = 9
    var minute: Int = 0
    var scope: String = ReminderScope.everyDay.rawValue
    var isEnabled: Bool = true
    /// After the reminder, nudge again every hour until the habit is done.
    var repeatsHourly: Bool = false
    var habit: Habit?

    init(
        id: UUID = UUID(),
        hour: Int = 9,
        minute: Int = 0,
        scope: ReminderScope = .everyDay,
        isEnabled: Bool = true,
        repeatsHourly: Bool = false,
        habit: Habit? = nil
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.scope = scope.rawValue
        self.isEnabled = isEnabled
        self.repeatsHourly = repeatsHourly
        self.habit = habit
    }

    /// Non-persisted view of `scope`. Falls back to `.everyDay`.
    var reminderScope: ReminderScope {
        get { ReminderScope(rawValue: scope) ?? .everyDay }
        set { scope = newValue.rawValue }
    }
}
