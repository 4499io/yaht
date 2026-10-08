import SwiftData
import SwiftUI

/// Sheet for creating a new habit (`init(habit: nil)`) or editing an existing
/// one. All editing happens on a plain ``HabitEditViewModel``; the SwiftData
/// model is only touched when the user taps Save. When editing, the bottom of
/// the form offers Delete (or Archive instead); the presenter performs it via
/// `onRemove` after the sheet closes.
struct HabitEditView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: HabitEditViewModel
    @State private var confirmingDelete = false
    private let onRemove: ((HabitRemoval) -> Void)?

    init(habit: Habit?, onRemove: ((HabitRemoval) -> Void)? = nil) {
        _viewModel = State(initialValue: HabitEditViewModel(habit: habit))
        self.onRemove = onRemove
    }

    var body: some View {
        NavigationStack {
            Form {
                IdentitySection(viewModel: viewModel)
                BasicsSection(viewModel: viewModel)
                KindSection(viewModel: viewModel)
                ScheduleSection(viewModel: viewModel)
                RemindersSection(viewModel: viewModel)
                if viewModel.isEditing, onRemove != nil {
                    deleteSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(viewModel.isEditing ? "Edit Habit" : "New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .tint(viewModel.selectedColor)
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

    // MARK: - Delete

    private var deleteSection: some View {
        Section {
            Button("Delete Habit", role: .destructive) {
                confirmingDelete = true
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(Theme.danger)
            .accessibilityIdentifier("habit-edit-delete")
            .confirmationDialog(
                "Delete “\(viewModel.trimmedName)”?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete Habit", role: .destructive) { remove(.delete) }
                Button("Archive Instead") { remove(.archive) }
                Button("Keep Habit", role: .cancel) {}
            } message: {
                Text("Its check-ins and reminders are removed on all your devices. This can’t be undone. Archiving hides it from Today but keeps its history.")
            }
        }
        .listRowBackground(Theme.surface)
    }

    // MARK: - Actions

    private func save() {
        let habit = viewModel.commit(store: store, modelContext: modelContext)
        Task { await NotificationScheduler.shared.reschedule(for: habit) }
        dismiss()
    }

    private func remove(_ removal: HabitRemoval) {
        onRemove?(removal)
        dismiss()
    }
}

/// Large emoji tile in the habit's color; tap it to type a new emoji.
private struct IdentitySection: View {
    @Bindable var viewModel: HabitEditViewModel

    var body: some View {
        Section {
            VStack(spacing: 10) {
                TextField("Emoji", text: $viewModel.emoji)
                    .font(.system(size: 44))
                    .multilineTextAlignment(.center)
                    .frame(width: 88, height: 88)
                    .background(
                        viewModel.selectedColor.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                    )
                    .accessibilityLabel("Emoji")
                    .accessibilityIdentifier("habit-edit-emoji")
                Text("Tap to change the emoji")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .listRowBackground(Color.clear)
    }
}

/// Name and color.
private struct BasicsSection: View {
    @Bindable var viewModel: HabitEditViewModel

    var body: some View {
        Section("Name") {
            TextField("e.g. Read 10 pages", text: $viewModel.name)
                .roundedFont(22)
                .textInputAutocapitalization(.sentences)
                .accessibilityLabel("Name")
                .accessibilityIdentifier("habit-edit-name")
            colorPicker
        }
        .listRowBackground(Theme.surface)
    }

    private var colorPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 5), spacing: 6) {
            ForEach(Theme.habitColors, id: \.hex) { color in
                let hex = color.hex
                let fill = Color(hex: hex) ?? .accentColor
                let isSelected = hex.caseInsensitiveCompare(viewModel.colorHex) == .orderedSame
                Button {
                    viewModel.colorHex = hex
                } label: {
                    Circle()
                        .fill(fill)
                        .frame(width: 34, height: 34)
                        .padding(4)
                        .overlay {
                            Circle().strokeBorder(isSelected ? fill : .clear, lineWidth: 2.5)
                        }
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("habit-edit-color-\(hex)")
                .accessibilityLabel(Text(color.name))
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(.vertical, 4)
    }
}

/// Habit type (yes/no vs count) and the count's daily goal and unit.
private struct KindSection: View {
    @Bindable var viewModel: HabitEditViewModel

    var body: some View {
        Section("Track") {
            HStack(spacing: 8) {
                option(.binary, title: "Yes or no", subtitle: "Done once a day")
                option(.count, title: "Count", subtitle: "Glasses, pages, minutes")
            }
            .accessibilityIdentifier("habit-edit-kind")

            if viewModel.kind == .count {
                Stepper(
                    "Daily goal: \(viewModel.dailyTarget)",
                    value: $viewModel.dailyTarget,
                    in: 1...999
                )
                .accessibilityIdentifier("habit-edit-daily-target")

                TextField("Unit (e.g. glasses)", text: $viewModel.unit)
                    .accessibilityIdentifier("habit-edit-unit")
            }
        }
        .listRowBackground(Theme.surface)
    }

    private func option(_ kind: HabitKind, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        let isSelected = viewModel.kind == kind
        return Button {
            viewModel.kind = kind
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isSelected ? viewModel.selectedColor : Theme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(12)
            .background(
                isSelected ? viewModel.selectedColor.opacity(0.16) : Theme.raised,
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview("New Habit") {
    let container = try! ModelContainer(
        for: Habit.self, Reminder.self, HabitLog.self, HabitPause.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return HabitEditView(habit: nil)
        .environment(HabitStore(modelContext: container.mainContext))
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
