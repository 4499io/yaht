import SwiftUI

/// Schedule configuration: pick a ``ScheduleKind`` and its dependent controls.
struct ScheduleSection: View {
    @Environment(\.dynamicTypeSize) private var textSize
    @Bindable var viewModel: HabitEditViewModel

    /// Calendar weekday order (1 = Sunday ... 7 = Saturday) with short labels.
    private var weekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    var body: some View {
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: textSize >= .xxxLarge ? 1 : 2), spacing: 8) {
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
        } header: {
            Text("When")
        } footer: {
            if viewModel.scheduleKind == .specificWeekdays && !viewModel.hasSelectedWeekdays {
                Text("Choose at least one day to save this schedule.")
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .listRowBackground(Theme.surface)
    }

    private func chip(_ kind: ScheduleKind, _ title: LocalizedStringKey) -> some View {
        let isSelected = viewModel.scheduleKind == kind
        return Button {
            viewModel.scheduleKind = kind
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .fixedSize(horizontal: false, vertical: true)
                if isSelected {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }
            }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(isSelected ? Theme.onAccent(viewModel.colorHex) : Theme.textPrimary)
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
            ForEach(weekdays, id: \.self) { day in
                let selected = viewModel.isWeekdaySelected(day)
                Button {
                    viewModel.toggleWeekday(day)
                } label: {
                    Text(Calendar.current.shortStandaloneWeekdaySymbols[day - 1])
                        .font(.caption.weight(.semibold))
                        .frame(minWidth: 44, maxWidth: fillsWidth ? .infinity : nil, minHeight: 44)
                        .foregroundStyle(selected ? Theme.onAccent(viewModel.colorHex) : Theme.textSecondary)
                        .background(
                            selected ? viewModel.selectedColor : Theme.raised,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("habit-edit-weekday-\(day)")
                .accessibilityLabel(Text(Calendar.current.weekdaySymbols[day - 1]))
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

/// A single editable reminder: the time and its on/off switch on top, then
/// one labelled row per setting with its control on the trailing edge, so
/// both switches line up. Removing sits apart at the bottom, away from the
/// switches.
private struct ReminderRow: View {
    @Binding var reminder: ReminderDraft
    /// "Some days" habits remind only on their chosen days, so the reminder's
    /// own day choice is hidden.
    let followsHabitDays: Bool
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                DatePicker(
                    "Time",
                    selection: $reminder.time,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .accessibilityIdentifier("habit-edit-reminder-time")

                Spacer(minLength: 8)

                Toggle("Reminder on", isOn: $reminder.isEnabled)
                    .labelsHidden()
                    .accessibilityIdentifier("habit-edit-reminder-enabled")
            }

            VStack(spacing: 14) {
                SettingRow(title: "Days", systemImage: "calendar") {
                    if followsHabitDays {
                        Text("Habit's days")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textTertiary)
                    } else {
                        Picker("Days", selection: $reminder.scope) {
                            Text("Every day").tag(ReminderScope.everyDay)
                            Text("Weekdays").tag(ReminderScope.weekdaysOnly)
                            Text("Weekends").tag(ReminderScope.weekendsOnly)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                        .accessibilityIdentifier("habit-edit-reminder-scope")
                    }
                }

                SettingRow(title: "Every hour until done", systemImage: "arrow.clockwise") {
                    Toggle("Every hour until done", isOn: $reminder.repeatsHourly)
                        .labelsHidden()
                        .accessibilityIdentifier("habit-edit-reminder-hourly")
                }
            }
            .disabled(!reminder.isEnabled)
            .opacity(reminder.isEnabled ? 1 : 0.45)

            // Borderless: in a Form row, default-styled buttons make the
            // whole row their tap target.
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "trash")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.danger)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove reminder")
            .accessibilityIdentifier("habit-edit-reminder-remove")
        }
        .padding(.top, 10)
    }
}

/// An icon and title on the leading edge, a control on the trailing edge.
private struct SettingRow<Control: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    @ViewBuilder let control: Control

    var body: some View {
        AdaptiveStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            control
        }
        .frame(minHeight: 32)
    }
}
