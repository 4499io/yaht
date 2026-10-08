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
        Section("When") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                chip(.daily, "Every day")
                chip(.specificWeekdays, "Some days")
                chip(.timesPerWeek, "Times a week")
                chip(.everyNDays, "Every few days")
            }
            .padding(.vertical, 4)
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
        .listRowBackground(Theme.surface)
    }

    private func chip(_ kind: ScheduleKind, _ title: LocalizedStringKey) -> some View {
        let isSelected = viewModel.scheduleKind == kind
        return Button {
            viewModel.scheduleKind = kind
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(isSelected ? Theme.onAccent : Theme.textPrimary)
                .background(
                    isSelected ? viewModel.selectedColor : Theme.raised,
                    in: Capsule()
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.borderless)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
                        .foregroundStyle(selected ? Theme.onAccent : Theme.textSecondary)
                        .background(
                            selected ? viewModel.selectedColor : Theme.raised,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("habit-edit-weekday-\(day.weekday)")
                .accessibilityLabel(Text(Calendar.current.weekdaySymbols[day.weekday - 1]))
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
    }
}

/// Reminder list: time, scope, enable and hourly toggles per row, with add/delete.
struct RemindersSection: View {
    @Bindable var viewModel: HabitEditViewModel

    var body: some View {
        Section {
            ForEach($viewModel.reminders) { $reminder in
                ReminderRow(reminder: $reminder, followsHabitDays: viewModel.scheduleKind == .specificWeekdays) {
                    viewModel.removeReminder(id: reminder.id)
                }
            }

            Button {
                viewModel.addReminder()
            } label: {
                Label("Add reminder", systemImage: "plus.circle.fill")
            }
            .accessibilityIdentifier("habit-edit-add-reminder")
        } header: {
            Text("Reminders")
        }
        .listRowBackground(Theme.surface)
    }
}

/// A single editable reminder draft row; its bin button removes it.
private struct ReminderRow: View {
    @Binding var reminder: ReminderDraft
    /// "Some days" habits remind only on their chosen days, so the reminder's
    /// own day choice is hidden.
    let followsHabitDays: Bool
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
                        .foregroundStyle(Theme.danger)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove reminder")
                .accessibilityIdentifier("habit-edit-reminder-remove")
            }

            if followsHabitDays {
                Text("On the habit's days")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
            } else {
                Picker("Days", selection: $reminder.scope) {
                    Text("Every day").tag(ReminderScope.everyDay)
                    Text("Weekdays").tag(ReminderScope.weekdaysOnly)
                    Text("Weekends").tag(ReminderScope.weekendsOnly)
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("habit-edit-reminder-scope")
            }

            Toggle(isOn: $reminder.repeatsHourly) {
                Text("Every hour until done")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            .disabled(!reminder.isEnabled)
            .accessibilityIdentifier("habit-edit-reminder-hourly")
        }
        .padding(.vertical, 4)
    }
}
