import SwiftUI

/// Schedule configuration: pick a ``ScheduleKind`` and its dependent controls.
struct ScheduleSection: View {
    @Bindable var viewModel: HabitEditViewModel

    /// Calendar weekday order (1 = Sunday ... 7 = Saturday) with short labels.
    private let weekdays: [(weekday: Int, label: String)] = [
        (1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"),
        (5, "Thu"), (6, "Fri"), (7, "Sat")
    ]

    var body: some View {
        Section("Schedule") {
            Picker("Repeats", selection: $viewModel.scheduleKind) {
                Text("Every day").tag(ScheduleKind.daily)
                Text("Specific days").tag(ScheduleKind.specificWeekdays)
                Text("Every N days").tag(ScheduleKind.everyNDays)
                Text("Times per week").tag(ScheduleKind.timesPerWeek)
            }
            .accessibilityIdentifier("habit-edit-schedule-kind")

            switch viewModel.scheduleKind {
            case .daily:
                EmptyView()
            case .specificWeekdays:
                weekdayToggles
            case .everyNDays:
                Stepper(
                    "Every \(viewModel.intervalDays) day\(viewModel.intervalDays == 1 ? "" : "s")",
                    value: $viewModel.intervalDays,
                    in: 1...365
                )
                .accessibilityIdentifier("habit-edit-interval-days")
            case .timesPerWeek:
                Stepper(
                    "\(viewModel.weeklyTarget) time\(viewModel.weeklyTarget == 1 ? "" : "s") per week",
                    value: $viewModel.weeklyTarget,
                    in: 1...7
                )
                .accessibilityIdentifier("habit-edit-weekly-target")
            }
        }
    }

    private var weekdayToggles: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(weekdays, id: \.weekday) { day in
                    let selected = viewModel.isWeekdaySelected(day.weekday)
                    Button {
                        viewModel.toggleWeekday(day.weekday)
                    } label: {
                        Text(day.label)
                            .font(.caption.weight(.semibold))
                            .frame(minWidth: 44, minHeight: 44)
                            .foregroundStyle(selected ? Cyberdream.textPrimary : Cyberdream.textSecondary)
                            .background(
                                selected ? AnyShapeStyle(viewModel.selectedColor) : AnyShapeStyle(.ultraThinMaterial),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("habit-edit-weekday-\(day.weekday)")
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 4)
        }
    }
}

/// Reminder list: time, scope and enable toggle per row, with add/delete.
struct RemindersSection: View {
    @Bindable var viewModel: HabitEditViewModel

    var body: some View {
        Section("Reminders") {
            ForEach($viewModel.reminders) { $reminder in
                ReminderRow(reminder: $reminder)
            }
            .onDelete { viewModel.removeReminders(at: $0) }

            Button {
                viewModel.addReminder()
            } label: {
                Label("Add reminder", systemImage: "plus.circle.fill")
            }
            .accessibilityIdentifier("habit-edit-add-reminder")
        }
    }
}

/// A single editable reminder draft row.
private struct ReminderRow: View {
    @Binding var reminder: ReminderDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                DatePicker(
                    "Time",
                    selection: $reminder.time,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .accessibilityIdentifier("habit-edit-reminder-time")

                Spacer()

                Toggle("Enabled", isOn: $reminder.isEnabled)
                    .labelsHidden()
                    .accessibilityIdentifier("habit-edit-reminder-enabled")
            }

            Picker("Days", selection: $reminder.scope) {
                Text("Every day").tag(ReminderScope.everyDay)
                Text("Weekdays").tag(ReminderScope.weekdaysOnly)
                Text("Weekends").tag(ReminderScope.weekendsOnly)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("habit-edit-reminder-scope")
        }
        .padding(.vertical, 4)
    }
}
