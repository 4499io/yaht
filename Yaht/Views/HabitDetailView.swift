import SwiftData
import SwiftUI

/// What the editor asked to do with a habit when it closed.
enum HabitRemoval {
    case delete
    case archive
}

/// Detail screen for one habit: identity, streak and this week's progress, a
/// check-in button, a month calendar and lifetime numbers. "Edit" opens the
/// editor; deleting or archiving there closes this screen first.
struct HabitDetailView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    private let habit: Habit
    @State private var showingEditor = false
    @State private var pendingRemoval: HabitRemoval?

    init(habit: Habit) {
        self.habit = habit
    }

    var body: some View {
        let today = Date()
        let stats = HabitStats(habit: habit, today: today)
        let week = habit.weekProgress(containing: today)
        ScrollView {
            VStack(spacing: 18) {
                header
                HStack(spacing: 10) {
                    streakCard(stats)
                    weekCard(week)
                }
                .fixedSize(horizontal: false, vertical: true)
                CheckInButton(habit: habit, day: today)
                Card(padding: 16) {
                    MonthCalendarView(habit: habit)
                }
                HStack(spacing: 10) {
                    numberTile("\(stats.bestStreak)", caption: "best streak, days")
                    numberTile("\(stats.last30Percent)%", caption: "last 30 days")
                    numberTile("\(stats.totalCompleted)", caption: "check-ins")
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditor = true }
                    .accessibilityIdentifier("habit-detail-edit-button")
            }
        }
        .sheet(isPresented: $showingEditor, onDismiss: {
            if pendingRemoval != nil { dismiss() }
        }) {
            HabitEditView(habit: habit) { removal in
                pendingRemoval = removal
            }
        }
        .onDisappear(perform: applyPendingRemoval)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 16) {
            HabitTile(emoji: habit.emoji, color: habit.color, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name.isEmpty ? "Untitled" : habit.name)
                    .font(.rounded(30, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    private func streakCard(_ stats: HabitStats) -> some View {
        Card(cornerRadius: 22, padding: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current streak")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
                Text("\(stats.currentStreak)")
                    .font(.rounded(44, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(habit.color)
                Text(stats.currentStreak == 1 ? "day in a row" : "days in a row")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func weekCard(_ week: WeekProgress) -> some View {
        Card(cornerRadius: 22, padding: 16) {
            HStack(spacing: 12) {
                ZStack {
                    ProgressRing(progress: week.fraction, color: habit.color, lineWidth: 8)
                    Text("\(week.completed)/\(week.target)")
                        .font(.rounded(16, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                }
                .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text("This week")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                    Text(week.isMet ? "Target met" : "\(max(week.target - week.completed, 0)) more to go")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func numberTile(_ value: String, caption: LocalizedStringKey) -> some View {
        Card(cornerRadius: 18, padding: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.rounded(24, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts = [habit.scheduleSummary]
        if let goal = habit.goalSummary { parts.append(goal) }
        let firstReminder = (habit.reminders ?? [])
            .filter(\.isEnabled)
            .min { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        if let firstReminder {
            let time = ReminderDraft.date(hour: firstReminder.hour, minute: firstReminder.minute)
            parts.append(String(localized: "reminder \(time.formatted(date: .omitted, time: .shortened))"))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Removal

    private func applyPendingRemoval() {
        guard let removal = pendingRemoval else { return }
        pendingRemoval = nil
        let id = habit.id
        switch removal {
        case .delete: store.delete(habit)
        case .archive: store.archive(habit)
        }
        Task { await NotificationScheduler.shared.cancel(forHabitID: id) }
    }
}

/// Full-width check-in for today. Yes/no habits toggle; count habits add one.
private struct CheckInButton: View {
    @Environment(HabitStore.self) private var store
    let habit: Habit
    let day: Date

    var body: some View {
        let done = habit.isCompleted(on: day)
        Button {
            switch habit.habitKind {
            case .binary: store.toggleCompletion(for: habit, on: day)
            case .count: store.increment(habit, on: day, by: 1)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: habit.habitKind == .count && !done ? "plus" : "checkmark")
                    .font(.system(size: 17, weight: .heavy))
                Text(label(done: done))
            }
            .font(.rounded(17))
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(done ? habit.color : Theme.onAccent)
            .background(done ? Color.clear : habit.color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(done ? habit.color.opacity(0.5) : .clear, lineWidth: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: done) { _, isDone in isDone }
        .accessibilityHint(habit.habitKind == .binary && done ? Text("Double-tap to undo") : Text(""))
        .accessibilityIdentifier("habit-detail-check-in")
    }

    private func label(done: Bool) -> String {
        switch habit.habitKind {
        case .binary:
            return done ? String(localized: "Done today") : String(localized: "Check in today")
        case .count:
            let progress = "\(habit.dayCount(on: day))/\(max(habit.dailyTarget, 1))"
            return done ? String(localized: "Done today · \(progress)") : String(localized: "Add one · \(progress)")
        }
    }
}

#Preview {
    NavigationStack {
        HabitDetailView(habit: Habit(name: "Read", emoji: "📚", colorHex: Theme.habitPaletteHex[2]))
    }
    .preferredColorScheme(.dark)
}
