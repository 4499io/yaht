import SwiftData
import SwiftUI

/// Home: the day's ring and headline, the last seven days, the habit list and
/// the 20-week activity grid. Tapping a day in the strip shows and logs that
/// day instead of today, for check-ins you forgot. With no habits yet it shows
/// the starter picker.
struct HabitListView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        let visible = habits.filter { calendar.startOfDay(for: $0.createdAt) <= day }
        let scheduled = visible.filter { $0.isOnToday(day) }
        let other = visible.filter { !$0.isOnToday(day) }
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header(day: day, today: today, calendar: calendar)
                TodaySummaryCard(habits: visible, day: day, isToday: day == today)
                WeekStrip(habits: habits, today: today, selected: day) { picked in
                    withAnimation(reduceMotion ? nil : .snappy) { selectedDay = picked == today ? nil : picked }
                }
                habitSection("On your list", habits: scheduled, day: day)
                if !other.isEmpty {
                    habitSection("Other habits", habits: other, day: day)
                }
                GlobalActivityGridView(habits: habits)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private func header(day: Date, today: Date, calendar: Calendar) -> some View {
        let isToday = day == today
        return AdaptiveStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day, format: .dateTime.weekday(.wide).day().month(.wide))
                    .roundedFont(13, weight: .semibold)
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
                .roundedFont(34, weight: .heavy)
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.isHeader)
            }
            if !isToday {
                Button {
                    withAnimation(reduceMotion ? nil : .snappy) { selectedDay = nil }
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

    private func habitSection(_ title: LocalizedStringKey, habits: [Habit], day: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: title, detail: "\(habits.count)")
            if habits.isEmpty {
                Text("Nothing scheduled for this day.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(habits) { habit in
                    HabitRowView(habit: habit, day: day)
                }
            }
        }
    }
}

/// The day at a glance: one ring segment per habit on today's list, the count
/// done, and what is still open.
struct TodaySummaryCard: View {
    @ScaledMetric(relativeTo: .title) private var ringSize: CGFloat = 124
    let habits: [Habit]
    let day: Date
    var isToday = true

    var body: some View {
        let due = habits.filter { $0.isOnToday(day) }
        let open = due.filter { !$0.isCompleted(on: day) }
        let doneCount = due.count - open.count
        Card(padding: 18) {
            AdaptiveStack(spacing: 20) {
                ZStack {
                    SegmentedRing(segments: due.map {
                        SegmentedRing.Segment(id: $0.id.uuidString, color: $0.color, isFilled: $0.isCompleted(on: day))
                    })
                    VStack(spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text(due.isEmpty ? "–" : "\(doneCount)")
                                .foregroundStyle(Theme.textPrimary)
                            if !due.isEmpty {
                                Text("/\(due.count)")
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                        .roundedFont(32, weight: .heavy)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        Text(due.isEmpty ? "rest day" : "done")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(width: min(ringSize, 180), height: min(ringSize, 180))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(due.isEmpty ? Text("No habits scheduled") : Text("\(doneCount) of \(due.count) habits done"))
                .accessibilityValue(Text(day, format: .dateTime.weekday(.wide).day().month()))

                VStack(alignment: .leading, spacing: 6) {
                    Text(headline(due: due.count, open: open.count))
                        .roundedFont(20)
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
        if due == 0 { return isToday ? "Nothing due today" : "Nothing was due" }
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
    @ScaledMetric(relativeTo: .caption) private var dayDiameter: CGFloat = 30
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
        ViewThatFits(in: .horizontal) {
            dayRow(fillsWidth: true)
            ScrollView(.horizontal) {
                dayRow(fillsWidth: false)
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.trailing)
        }
    }

    private func dayRow(fillsWidth: Bool) -> some View {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: today)
        let diameter = min(dayDiameter, 72)
        return HStack(spacing: 4) {
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
                                .roundedFont(12, weight: .bold)
                                .monospacedDigit()
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .frame(width: diameter, height: diameter)
                    }
                    .frame(minWidth: max(diameter + 14, 44), maxWidth: fillsWidth ? .infinity : nil)
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

#Preview("Today") {
    let fixture = try! PreviewHabits()
    return NavigationStack {
        HabitListView()
    }
    .environment(fixture.store)
    .modelContainer(fixture.container)
    .preferredColorScheme(.dark)
}

#Preview("Today · Accessibility text") {
    let fixture = try! PreviewHabits()
    return NavigationStack { HabitListView() }
        .environment(fixture.store)
        .modelContainer(fixture.container)
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
}
