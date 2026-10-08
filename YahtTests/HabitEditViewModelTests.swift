import Foundation
import Testing
@testable import Yaht

@MainActor
struct HabitEditViewModelTests {
    @Test func anEmptyWeekdayScheduleCannotBeSaved() {
        let viewModel = HabitEditViewModel(habit: nil)
        viewModel.name = "Walk"
        viewModel.scheduleKind = .specificWeekdays
        viewModel.scheduleDaysMask = 0
        #expect(!viewModel.canSave)
        viewModel.toggleWeekday(2)
        #expect(viewModel.canSave)
        viewModel.toggleWeekday(2)
        #expect(!viewModel.canSave)
    }

    @Test func otherSchedulesDoNotRequireWeekdaySelection() {
        let viewModel = HabitEditViewModel(habit: nil)
        viewModel.name = "Read"
        viewModel.scheduleDaysMask = 0
        for schedule in [ScheduleKind.daily, .everyNDays, .timesPerWeek] {
            viewModel.scheduleKind = schedule
            #expect(viewModel.canSave)
        }
        viewModel.name = "   "
        #expect(!viewModel.canSave)
    }

    @Test func removeReminderByIDKeepsTheOthers() {
        let viewModel = HabitEditViewModel(habit: nil)
        viewModel.addReminder()
        viewModel.addReminder()
        viewModel.addReminder()
        let removed = viewModel.reminders[1].id
        let kept = [viewModel.reminders[0].id, viewModel.reminders[2].id]

        viewModel.removeReminder(id: removed)

        #expect(viewModel.reminders.map(\.id) == kept)
    }

    @Test func removingAnUnknownReminderChangesNothing() {
        let viewModel = HabitEditViewModel(habit: nil)
        viewModel.addReminder()
        let before = viewModel.reminders.map(\.id)

        viewModel.removeReminder(id: UUID())

        #expect(viewModel.reminders.map(\.id) == before)
    }
}
