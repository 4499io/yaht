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
    @State private var choosingPauseEnd = false

    init(habit: Habit) {
        self.habit = habit
    }

    var body: some View {
        let today = Date()
        let stats = HabitStats(habit: habit, today: today)
        let week = habit.weekGoal(containing: today)
        let streak = habit.weeklyStreak(today: today)
        ScrollView {
            VStack(spacing: 18) {
                header
                HStack(spacing: 10) {
                    streakCard(streak)
                    weekCard(week)
                }
                .fixedSize(horizontal: false, vertical: true)
                CheckInButton(habit: habit, day: today)
                PauseControl(habit: habit, today: today, choosingEnd: $choosingPauseEnd)
                Card(padding: 16) {
                    MonthCalendarView(habit: habit)
                }
                HStack(spacing: 10) {
                    numberTile("\(streak.best)", caption: "best streak, weeks")
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
                    .roundedFont(30, weight: .heavy)
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

    private func streakCard(_ streak: WeeklyStreak) -> some View {
        Card(cornerRadius: 22, padding: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Streak")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
                Text("\(streak.current)")
                    .roundedFont(44, weight: .heavy)
                    .monospacedDigit()
                    .foregroundStyle(habit.color)
                Text(streak.current == 1 ? "week in a row" : "weeks in a row")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func weekCard(_ week: WeekGoal) -> some View {
        Card(cornerRadius: 22, padding: 16) {
            HStack(spacing: 12) {
                ZStack {
                    ProgressRing(progress: week.fraction, color: habit.color, lineWidth: 8)
                    Text(week.isNeutral ? "–" : "\(week.completed)/\(week.required)")
                        .roundedFont(16, weight: .heavy)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                }
                .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text("This week")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                    Text(weekStatus(week))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    if week.restDays > 0, !week.isMet {
                        Text("1 rest day allowed")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func weekStatus(_ week: WeekGoal) -> String {
        if week.isNeutral { return String(localized: "Nothing due") }
        if week.isMet { return String(localized: "Goal met") }
        return String(localized: "\(week.required - week.completed) more to go")
    }

    private func numberTile(_ value: String, caption: LocalizedStringKey) -> some View {
        Card(cornerRadius: 18, padding: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .roundedFont(24, weight: .heavy)
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
            .roundedFont(17)
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(done ? habit.color : Theme.onAccent(habit.colorHex))
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

/// Pause a habit for illness or a holiday, or resume it. Paused days are not
/// due, keep the streak intact and hold back reminders. A pause can also cover
/// last week after the fact, for when the break was not planned.
private struct PauseControl: View {
    @Environment(HabitStore.self) private var store
    let habit: Habit
    let today: Date
    @Binding var choosingEnd: Bool
    @State private var endDate = Date()

    var body: some View {
        let calendar = Calendar.current
        if let pause = habit.pause(covering: today) {
            HStack(spacing: 12) {
                Image(systemName: "pause.circle.fill")
                    .font(.title2)
                    .foregroundStyle(habit.color)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paused until \(pause.end, format: .dateTime.weekday(.wide).day().month())")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Your streak is safe and reminders are off.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 8)
                Button("Resume") { store.resume(habit, today: today) }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(habit.color)
                    .accessibilityIdentifier("habit-detail-resume")
            }
            .padding(14)
            .background(habit.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            Menu {
                Button("Today") { pause(days: 1) }
                Button("1 week") { pause(days: 7) }
                Button("2 weeks") { pause(days: 14) }
                Button("Until a date…") {
                    endDate = calendar.date(byAdding: .day, value: 7, to: today) ?? today
                    choosingEnd = true
                }
                if let lastWeek = Self.lastWeek(before: today, calendar: calendar), !habit.isPaused(on: lastWeek.start) {
                    Divider()
                    Button("Last week, I was away") {
                        store.pause(habit, from: lastWeek.start, through: lastWeek.end)
                    }
                }
            } label: {
                Label("Pause habit", systemImage: "pause.circle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .foregroundStyle(Theme.textSecondary)
            .accessibilityIdentifier("habit-detail-pause")
            .sheet(isPresented: $choosingEnd) {
                NavigationStack {
                    DatePicker(
                        "Paused until",
                        selection: $endDate,
                        in: today...(calendar.date(byAdding: .day, value: HabitStore.maxPauseDays - 1, to: today) ?? today),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(habit.color)
                    .padding()
                    .navigationTitle("Pause until")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { choosingEnd = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Pause") {
                                store.pause(habit, from: today, through: endDate)
                                choosingEnd = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func pause(days: Int) {
        let end = Calendar.current.date(byAdding: .day, value: days - 1, to: today) ?? today
        store.pause(habit, from: today, through: end)
    }

    /// First and last day of the week before the one containing `date`.
    static func lastWeek(before date: Date, calendar: Calendar) -> (start: Date, end: Date)? {
        guard
            let thisWeek = calendar.dateInterval(of: .weekOfYear, for: date),
            let start = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek.start),
            let end = calendar.date(byAdding: .day, value: -1, to: thisWeek.start)
        else { return nil }
        return (start, end)
    }
}
