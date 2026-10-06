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

    /// Seven equal-width 44-point targets fill the row when they fit; at
    /// larger Dynamic Type sizes or very narrow widths the row scrolls instead
    /// of shrinking the targets.
    private var weekdayToggles: some View {
        ViewThatFits(in: .horizontal) {
            weekdayRow(fillsWidth: true)
            ScrollView(.horizontal) {
                weekdayRow(fillsWidth: false)
            }
        }
        .padding(.vertical, 4)
    }

    private func weekdayRow(fillsWidth: Bool) -> some View {
        HStack(spacing: 6) {
            ForEach(weekdays, id: \.weekday) { day in
                let selected = viewModel.isWeekdaySelected(day.weekday)
                Button {
                    viewModel.toggleWeekday(day.weekday)
                } label: {
                    Text(day.label)
                        .font(.caption.weight(.semibold))
                        .frame(minWidth: 44, maxWidth: fillsWidth ? .infinity : nil, minHeight: 44)
                        .foregroundStyle(selected ? Cyberdream.textPrimary : Cyberdream.textSecondary)
                        .background(
                            selected ? AnyShapeStyle(viewModel.selectedColor) : AnyShapeStyle(.ultraThinMaterial),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("habit-edit-weekday-\(day.weekday)")
                .accessibilityLabel(Text(Calendar.current.weekdaySymbols[day.weekday - 1]))
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
    }
}

/// Reminder list: time, scope and enable toggle per row, with add/delete.
struct RemindersSection: View {
    @Bindable var viewModel: HabitEditViewModel

    var body: some View {
        Section {
            ForEach($viewModel.reminders) { $reminder in
                ReminderRow(reminder: $reminder) {
                    viewModel.removeReminder(id: reminder.id)
                }
            }
            .onDelete { viewModel.removeReminders(at: $0) }

            Button {
                viewModel.addReminder()
            } label: {
                Label("Add reminder", systemImage: "plus.circle.fill")
            }
            .accessibilityIdentifier("habit-edit-add-reminder")
        } header: {
            Text("Reminders")
        } footer: {
            if !viewModel.reminders.isEmpty {
                Text("Remove a reminder with its bin button or by swiping it left.")
            }
        }
    }
}

/// A single editable reminder draft row.
///
/// Days use a menu rather than a full-width segmented control: a segmented
/// control claims horizontal drags, which blocked swipe-to-delete on the row.
/// The visible remove button keeps deletion discoverable either way.
private struct ReminderRow: View {
    @Binding var reminder: ReminderDraft
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                DatePicker(
                    "Time",
                    selection: $reminder.time,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .accessibilityIdentifier("habit-edit-reminder-time")

                Spacer(minLength: 0)

                Toggle("Enabled", isOn: $reminder.isEnabled)
                    .labelsHidden()
                    .accessibilityIdentifier("habit-edit-reminder-enabled")

                // Borderless: in a Form row, default-styled buttons make the
                // whole row their tap target.
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove reminder")
                .accessibilityIdentifier("habit-edit-reminder-remove")
            }

            Picker("Days", selection: $reminder.scope) {
                Text("Every day").tag(ReminderScope.everyDay)
                Text("Weekdays").tag(ReminderScope.weekdaysOnly)
                Text("Weekends").tag(ReminderScope.weekendsOnly)
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("habit-edit-reminder-scope")
        }
        .padding(.vertical, 4)
    }
}
