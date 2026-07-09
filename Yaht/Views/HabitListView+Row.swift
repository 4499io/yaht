import SwiftData
import SwiftUI

/// A single habit row: emoji + name + today's status on the left (tap to open
/// detail), and a completion / increment control on the right.
struct HabitRowView: View {
    let habit: Habit
    let day: Date

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                NavigationLink {
                    HabitDetailView(habit: habit)
                } label: {
                    rowLabel
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("habit-row-\(habit.id.uuidString)")

                HabitCompleteControl(habit: habit, day: day)
            }
        }
    }

    private var rowLabel: some View {
        HStack(spacing: 12) {
            Text(habit.emoji.isEmpty ? "•" : habit.emoji)
                .font(.title2)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name.isEmpty ? "Untitled" : habit.name)
                    .font(.headline)
                    .foregroundStyle(Cyberdream.textPrimary)
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(Cyberdream.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private var statusText: String {
        switch habit.habitKind {
        case .binary:
            return habit.isCompleted(on: day) ? "Done today" : "Not done"
        case .count:
            return "\(habit.dayCount(on: day))/\(max(habit.dailyTarget, 1)) \(habit.unit ?? "")"
                .trimmingCharacters(in: .whitespaces)
        }
    }
}

/// The trailing control that records progress for `day` without navigating.
struct HabitCompleteControl: View {
    @Environment(HabitStore.self) private var store
    let habit: Habit
    let day: Date

    var body: some View {
        switch habit.habitKind {
        case .binary:
            binaryButton
        case .count:
            countControl
        }
    }

    private var binaryButton: some View {
        let done = habit.isCompleted(on: day)
        return Button {
            store.toggleCompletion(for: habit, on: day)
        } label: {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.title)
                .foregroundStyle(done ? habit.color : Cyberdream.textSecondary)
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(done ? "Mark not done" : "Mark done")
        .accessibilityIdentifier("habit-complete-\(habit.id.uuidString)")
    }

    private var countControl: some View {
        let done = habit.isCompleted(on: day)
        return HStack(spacing: 8) {
            Text("\(habit.dayCount(on: day))/\(max(habit.dailyTarget, 1))")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(done ? habit.color : Cyberdream.textPrimary)
            Button {
                store.increment(habit, on: day, by: 1)
            } label: {
                Image(systemName: "plus")
                    .font(.headline)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Increment")
            .accessibilityIdentifier("habit-increment-\(habit.id.uuidString)")
        }
    }
}
