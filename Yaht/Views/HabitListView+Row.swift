import SwiftData
import SwiftUI

/// A habit row on Today: identity tile, name and a short note, the last seven
/// days, and the check button. Tapping anywhere but the button opens the detail.
struct HabitRowView: View {
    let habit: Habit
    let day: Date

    var body: some View {
        let done = habit.isCompleted(on: day)
        HStack(spacing: 12) {
            NavigationLink {
                HabitDetailView(habit: habit)
            } label: {
                HStack(spacing: 12) {
                    HabitTile(emoji: habit.emoji, color: habit.color)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(habit.name.isEmpty ? "Untitled" : habit.name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Text(note)
                                .font(.footnote)
                                .foregroundStyle(Theme.textTertiary)
                                .lineLimit(1)
                        }
                        HStack(spacing: 8) {
                            LastSevenDays(habit: habit, day: day)
                            StreakBadge(weeks: habit.weeklyStreak(today: day).current, color: habit.color)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("habit-row-\(habit.id.uuidString)")

            HabitCheckButton(habit: habit, day: day)
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 8)
        .frame(minHeight: 72)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(done ? habit.color.opacity(0.3) : Theme.hairline, lineWidth: 1)
        }
    }

    private var note: String {
        if let pause = habit.pause(covering: day) {
            return String(localized: "Paused until \(pause.end.formatted(.dateTime.day().month()))")
        }
        if habit.schedule == .timesPerWeek {
            let week = habit.weekGoal(containing: day)
            return String(localized: "\(week.completed) of \(week.required) this week")
        }
        if let goal = habit.goalSummary { return goal }
        if !habit.isDue(on: day) { return String(localized: "Not due") }
        return habit.scheduleSummary
    }
}

/// Flame and week count, shown once a habit has a weekly streak.
private struct StreakBadge: View {
    let weeks: Int
    let color: Color

    var body: some View {
        if weeks > 0 {
            HStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("\(weeks)w")
                    .roundedFont(12, weight: .heavy)
                    .monospacedDigit()
            }
            .foregroundStyle(color)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(weeks == 1 ? Text("1 week in a row") : Text("\(weeks) weeks in a row"))
        }
    }
}

/// Seven short bars, oldest first, filled in the habit's color on done days.
private struct LastSevenDays: View {
    let habit: Habit
    let day: Date

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: day)
        let days = (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        let done = days.filter { habit.isCompleted(on: $0, calendar: calendar) }.count
        HStack(spacing: 4) {
            ForEach(days, id: \.self) { date in
                let progress = habit.progress(on: date, calendar: calendar)
                Capsule()
                    .fill(progress >= 1 ? habit.color : (progress > 0 ? habit.color.opacity(0.5) : Theme.track))
                    .frame(width: 18, height: 5)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Done \(done) of the last 7 days")
    }
}

/// The ring that records today's progress without leaving the list.
///
/// Yes/no habits toggle. Count habits add one per tap and show "n/goal" until
/// the goal is met; a long press offers undo and reset. The ring fills with the
/// habit's color as progress grows and becomes a solid check when done.
struct HabitCheckButton: View {
    @Environment(HabitStore.self) private var store
    let habit: Habit
    let day: Date
    var diameter: CGFloat = 40

    var body: some View {
        let progress = habit.progress(on: day)
        let done = progress >= 1
        Button(action: tap) {
            ZStack {
                if done {
                    Circle().fill(habit.color)
                    Image(systemName: "checkmark")
                        .font(.system(size: diameter * 0.4, weight: .heavy))
                        .foregroundStyle(Theme.onAccent(habit.colorHex))
                } else {
                    ProgressRing(progress: progress, color: habit.color, lineWidth: 3)
                    if habit.habitKind == .count {
                        Text("\(habit.dayCount(on: day))/\(max(habit.dailyTarget, 1))")
                            .roundedFont(diameter * 0.3, weight: .heavy)
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .foregroundStyle(habit.color)
                            .padding(4)
                    }
                }
            }
            .frame(width: diameter, height: diameter)
            .frame(width: max(diameter + 12, 44), height: max(diameter + 12, 44))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: done) { _, isDone in isDone }
        .contextMenu {
            if habit.habitKind == .count {
                Button("Undo one", systemImage: "minus") { store.increment(habit, on: day, by: -1) }
                Button("Reset today", systemImage: "arrow.counterclockwise") { store.setCount(habit, on: day, to: 0) }
            }
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier(
            habit.habitKind == .count ? "habit-increment-\(habit.id.uuidString)" : "habit-complete-\(habit.id.uuidString)"
        )
    }

    private func tap() {
        switch habit.habitKind {
        case .binary:
            store.toggleCompletion(for: habit, on: day)
        case .count:
            store.increment(habit, on: day, by: 1)
        }
    }

    private var accessibilityLabel: Text {
        switch habit.habitKind {
        case .binary:
            return habit.isCompleted(on: day) ? Text("Mark \(habit.name) not done") : Text("Mark \(habit.name) done")
        case .count:
            return Text("Add one to \(habit.name)")
        }
    }

    private var accessibilityValue: Text {
        switch habit.habitKind {
        case .binary:
            return habit.isCompleted(on: day) ? Text("Done") : Text("Not done")
        case .count:
            return Text("\(habit.dayCount(on: day)) of \(max(habit.dailyTarget, 1))")
        }
    }
}
