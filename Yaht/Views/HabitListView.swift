import SwiftData
import SwiftUI

/// Home: today's ring and headline, the last seven days, the habit list and the
/// 20-week activity grid. With no habits yet it shows the starter picker.
struct HabitListView: View {
    @Environment(HabitStore.self) private var store
    @Query(
        filter: #Predicate<Habit> { !$0.isArchived },
        sort: \Habit.sortOrder
    )
    private var habits: [Habit]

    @State private var showingEditor = false

    var body: some View {
        Group {
            if habits.isEmpty {
                StarterHabitsView { showingEditor = true }
            } else {
                content
            }
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !habits.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingEditor = true
                    } label: {
                        Label("New Habit", systemImage: "plus")
                    }
                    .accessibilityIdentifier("habit-list-add-button")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            HabitEditView(habit: nil)
        }
    }

    private var content: some View {
        // Re-read "today" on every render so the list rolls over at midnight
        // once anything on screen changes.
        let today = Date()
        return ScrollView {
            VStack(spacing: 18) {
                header(today)
                TodaySummaryCard(habits: habits, day: today)
                WeekStrip(habits: habits, today: today)
                VStack(spacing: 8) {
                    ForEach(orderedHabits(today)) { habit in
                        HabitRowView(habit: habit, day: today)
                    }
                }
                GlobalActivityGridView(habits: habits)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private func header(_ today: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(today, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.rounded(13, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Theme.textTertiary)
            Text("Today")
                .font(.rounded(34, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Habits on today's list first (in the user's order), then the rest.
    private func orderedHabits(_ today: Date) -> [Habit] {
        let onToday = habits.filter { $0.isOnToday(today) }
        let later = habits.filter { !$0.isOnToday(today) }
        return onToday + later
    }
}

/// The day at a glance: one ring segment per habit on today's list, the count
/// done, and what is still open.
struct TodaySummaryCard: View {
    let habits: [Habit]
    let day: Date

    var body: some View {
        let due = habits.filter { $0.isOnToday(day) }
        let open = due.filter { !$0.isCompleted(on: day) }
        let doneCount = due.count - open.count
        Card(padding: 18) {
            HStack(spacing: 20) {
                ZStack {
                    SegmentedRing(segments: due.map {
                        SegmentedRing.Segment(id: $0.id.uuidString, color: $0.color, isFilled: $0.isCompleted(on: day))
                    })
                    VStack(spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text("\(doneCount)")
                                .foregroundStyle(Theme.textPrimary)
                            Text("/\(due.count)")
                                .foregroundStyle(Theme.textDisabled)
                        }
                        .font(.rounded(32, weight: .heavy))
                        .monospacedDigit()
                        Text("done")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(width: 124, height: 124)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(doneCount) of \(due.count) habits done today")

                VStack(alignment: .leading, spacing: 6) {
                    Text(headline(due: due.count, open: open.count))
                        .font(.rounded(20))
                        .foregroundStyle(Theme.textPrimary)
                    Text(subline(due: due.count, open: open))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func headline(due: Int, open: Int) -> LocalizedStringKey {
        if due == 0 { return "Nothing due today" }
        switch open {
        case 0: return "All done. Nice."
        case 1: return "One to go"
        default: return "\(open) to go"
        }
    }

    private func subline(due: Int, open: [Habit]) -> String {
        if due == 0 { return String(localized: "Enjoy the day off.") }
        if open.isEmpty { return String(localized: "Every habit is checked off for today.") }
        let names = open.prefix(2).map { $0.name.isEmpty ? String(localized: "Untitled") : $0.name }
        return String(localized: "Next: \(names.formatted(.list(type: .and))).")
    }
}

/// The last seven days, today on the right, each with a ring for the share of
/// that day's habits that were done.
struct WeekStrip: View {
    let habits: [Habit]
    let today: Date

    var body: some View {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: today)
        let days = (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: start) }
        HStack(spacing: 4) {
            ForEach(days, id: \.self) { date in
                let isToday = calendar.isDate(date, inSameDayAs: start)
                let fraction = completion(on: date, calendar: calendar)
                VStack(spacing: 6) {
                    Text(date, format: .dateTime.weekday(.narrow))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isToday ? Theme.textPrimary : Theme.textTertiary)
                    ZStack {
                        ProgressRing(progress: fraction, color: Theme.textPrimary, lineWidth: 3)
                        Text(date, format: .dateTime.day())
                            .font(.rounded(12, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .frame(width: 30, height: 30)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(isToday ? Theme.raised : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(date, format: .dateTime.weekday(.wide).day().month()))
                .accessibilityValue(Text("\(Int((fraction * 100).rounded())) percent done"))
            }
        }
    }

    private func completion(on date: Date, calendar: Calendar) -> Double {
        let live = habits.filter { calendar.startOfDay(for: $0.createdAt) <= date }
        let due = live.filter { $0.isOnToday(date, calendar: calendar) }
        guard !due.isEmpty else { return 0 }
        let done = due.filter { $0.isCompleted(on: date, calendar: calendar) }.count
        return Double(done) / Double(due.count)
    }
}

#Preview {
    NavigationStack {
        HabitListView()
    }
    .preferredColorScheme(.dark)
}
