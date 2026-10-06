import SwiftData
import SwiftUI

/// Sheet for creating a new habit (`init(habit: nil)`) or editing an existing
/// one. All editing happens on a plain ``HabitEditViewModel``; the SwiftData
/// model is only touched when the user taps Save.
struct HabitEditView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: HabitEditViewModel

    init(habit: Habit?) {
        _viewModel = State(initialValue: HabitEditViewModel(habit: habit))
    }

    var body: some View {
        NavigationStack {
            Form {
                BasicsSection(viewModel: viewModel)
                KindSection(viewModel: viewModel)
                ScheduleSection(viewModel: viewModel)
                RemindersSection(viewModel: viewModel)
            }
            .navigationTitle(viewModel.isEditing ? "Edit Habit" : "New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        // Sheets present at window level — cap this one to iPhone width too so it
        // doesn't stretch on iPad (Guideline 4 — see 99issues #418).
        .phoneWidthConstrained()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
                .accessibilityIdentifier("habit-edit-cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save", action: save)
                .disabled(!viewModel.canSave)
                .accessibilityIdentifier("habit-edit-save")
        }
    }

    private func save() {
        let habit = viewModel.commit(store: store, modelContext: modelContext)
        Task { await NotificationScheduler.shared.reschedule(for: habit) }
        dismiss()
    }
}

/// Emoji, name and color-swatch picker.
private struct BasicsSection: View {
    @Bindable var viewModel: HabitEditViewModel

    var body: some View {
        Section("Basics") {
            HStack(spacing: 12) {
                TextField("Emoji", text: $viewModel.emoji)
                    .font(.system(size: 34))
                    .multilineTextAlignment(.center)
                    .frame(width: 56)
                    .accessibilityIdentifier("habit-edit-emoji")
                TextField("Name", text: $viewModel.name)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("habit-edit-name")
            }
            colorPicker
        }
    }

    private var colorPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Cyberdream.habitColors, id: \.hex) { color in
                    let hex = color.hex
                    let isSelected = hex.caseInsensitiveCompare(viewModel.colorHex) == .orderedSame
                    Button {
                        viewModel.colorHex = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex) ?? .accentColor)
                            .frame(width: 30, height: 30)
                            .overlay {
                                Circle()
                                    .strokeBorder(Cyberdream.textPrimary, lineWidth: isSelected ? 3 : 0)
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("habit-edit-color-\(hex)")
                    .accessibilityLabel(Text(color.name))
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 4)
        }
    }
}

/// Habit type (binary vs count) and count-only target/unit controls.
private struct KindSection: View {
    @Bindable var viewModel: HabitEditViewModel

    var body: some View {
        Section("Type") {
            Picker("Kind", selection: $viewModel.kind) {
                Text("Yes / No").tag(HabitKind.binary)
                Text("Count").tag(HabitKind.count)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("habit-edit-kind")

            if viewModel.kind == .count {
                Stepper(
                    "Daily target: \(viewModel.dailyTarget)",
                    value: $viewModel.dailyTarget,
                    in: 1...999
                )
                .accessibilityIdentifier("habit-edit-daily-target")

                TextField("Unit (e.g. glasses)", text: $viewModel.unit)
                    .accessibilityIdentifier("habit-edit-unit")
            }
        }
    }
}

#Preview("New Habit") {
    let container = try! ModelContainer(
        for: Habit.self, Reminder.self, HabitLog.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return HabitEditView(habit: nil)
        .environment(HabitStore(modelContext: container.mainContext))
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
