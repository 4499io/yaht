import SwiftData
import SwiftUI

/// Home: the day's ring and headline, the last seven days, the habit list and
/// the 20-week activity grid. Tapping a day in the strip shows and logs that
/// day instead of today, for check-ins you forgot. With no habits yet it shows
/// the starter picker.
struct HabitListView: View {
    @Environment(HabitStore.self) private var store
    @Query(
        filter: #Predicate<Habit> { !$0.isArchived },
        sort: \Habit.sortOrder
    )
    private var habits: [Habit]

    @State private var showingEditor = false
    /// A past day picked in the week strip; `nil` shows today.
    @State private var selectedDay: Date?

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
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day = selectedDay.flatMap { selected in
            WeekStrip.days(endingOn: today, calendar: calendar).contains(selected) && selected != today ? selected : nil
        } ?? today
        return ScrollView {
            VStack(spacing: 18) {
                header(day: day, today: today, calendar: calendar)
                TodaySummaryCard(habits: habits, day: day, isToday: day == today)
                WeekStrip(habits: habits, today: today, selected: day) { picked in
                    withAnimation(.snappy) { selectedDay = picked == today ? nil : picked }
                }
                VStack(spacing: 8) {
                    ForEach(orderedHabits(day)) { habit in
                        HabitRowView(habit: habit, day: day)
                    }
                }
                GlobalActivityGridView(habits: habits)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private func header(day: Date, today: Date, calendar: Calendar) -> some View {
        let isToday = day == today
        return HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.rounded(13, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Theme.textTertiary)
                Group {
                    if isToday {
                        Text("Today")
                    } else if calendar.isDateInYesterday(day) {
                        Text("Yesterday")
                    } else {
                        Text(day, format: .dateTime.weekday(.wide))
                    }
                }
                .font(.rounded(34, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 8)
            if !isToday {
                Button {
                    withAnimation(.snappy) { selectedDay = nil }
                } label: {
                    Label("Today", systemImage: "arrow.uturn.forward")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Theme.raised, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textPrimary)
                .frame(minHeight: 44)
                .accessibilityLabel("Back to today")
                .accessibilityIdentifier("home-back-to-today")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Habits on the day's list first (in the user's order), then the rest.
    private func orderedHabits(_ day: Date) -> [Habit] {
        let onDay = habits.filter { $0.isOnToday(day) }
        let rest = habits.filter { !$0.isOnToday(day) }
        return onDay + rest
    }
}

/// The day at a glance: one ring segment per habit on today's list, the count
/// done, and what is still open.
struct TodaySummaryCard: View {
    let habits: [Habit]
    let day: Date
    var isToday = true

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
        if due == 0 { return isToday ? String(localized: "Enjoy the day off.") : String(localized: "Nothing was due that day.") }
        if open.isEmpty {
            return isToday ? String(localized: "Every habit is checked off for today.") : String(localized: "Every habit was checked off that day.")
        }
        let names = open.prefix(2).map { $0.name.isEmpty ? String(localized: "Untitled") : $0.name }
        let list = names.formatted(.list(type: .and))
        return isToday ? String(localized: "Next: \(list).") : String(localized: "Still open: \(list).")
    }
}

/// The last seven days, today on the right, each with a ring for the share of
/// that day's habits that were done. Tapping a day selects it.
struct WeekStrip: View {
    let habits: [Habit]
    let today: Date
    let selected: Date
    let onSelect: (Date) -> Void

    /// The seven start-of-day dates ending on `today`, oldest first.
    static func days(endingOn today: Date, calendar: Calendar) -> [Date] {
        let start = calendar.startOfDay(for: today)
        return (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: start) }
    }

    var body: some View {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: today)
        HStack(spacing: 4) {
            ForEach(Self.days(endingOn: today, calendar: calendar), id: \.self) { date in
                let isSelected = calendar.isDate(date, inSameDayAs: selected)
                let isToday = calendar.isDate(date, inSameDayAs: start)
                let fraction = completion(on: date, calendar: calendar)
                Button { onSelect(date) } label: {
                    VStack(spacing: 6) {
                        Text(date, format: .dateTime.weekday(.narrow))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textTertiary)
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
                    .background(isSelected ? Theme.raised : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isToday ? Text("Today") : Text(date, format: .dateTime.weekday(.wide).day().month()))
                .accessibilityValue(Text("\(Int((fraction * 100).rounded())) percent done"))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
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
