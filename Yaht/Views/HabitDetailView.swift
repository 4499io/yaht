import SwiftData
import SwiftUI

/// Detail screen for a single habit: an oversized identity header, streak and
/// completion stats, a control to complete / increment today, and the per-habit
/// activity grid. The toolbar "Edit" action presents the habit editor as a sheet.
struct HabitDetailView: View {
    @Environment(HabitStore.self) private var store
    private let habit: Habit
    @State private var showingEditor = false

    init(habit: Habit) {
        self.habit = habit
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                todayCard
                statsGrid
                activityCard
            }
            .padding(16)
        }
        .navigationTitle(habit.name.isEmpty ? "Habit" : habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditor = true }
                    .accessibilityIdentifier("habit-detail-edit-button")
            }
        }
        .sheet(isPresented: $showingEditor) {
            HabitEditView(habit: habit)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 8) {
            Text(habit.emoji.isEmpty ? "•" : habit.emoji)
                .font(.system(size: 64))
            Text(habit.name.isEmpty ? "Untitled" : habit.name)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Cyberdream.textPrimary)
            Text(scheduleSummary)
                .font(.subheadline)
                .foregroundStyle(Cyberdream.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var todayCard: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.headline)
                        .foregroundStyle(Cyberdream.textPrimary)
                    Text(todayStatus)
                        .font(.subheadline)
                        .foregroundStyle(Cyberdream.textSecondary)
                }
                Spacer(minLength: 12)
                HabitCompleteControl(habit: habit, day: Date())
            }
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatTile(title: "Current Streak", value: "\(stats.currentStreak)", tint: habit.color)
            StatTile(title: "Best Streak", value: "\(stats.bestStreak)")
            StatTile(title: "Last 30 Days", value: "\(stats.last30Percent)%")
            StatTile(title: "Total Days", value: "\(stats.totalCompleted)")
        }
    }

    private var activityCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Activity")
                    .font(.headline)
                    .foregroundStyle(Cyberdream.textPrimary)
                ActivityGridView(habit: habit)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Derived text

    private var todayStatus: String {
        switch habit.habitKind {
        case .binary:
            return habit.isCompleted(on: Date()) ? "Completed" : "Not done yet"
        case .count:
            let unit = habit.unit.map { " \($0)" } ?? ""
            return "\(habit.dayCount(on: Date()))/\(max(habit.dailyTarget, 1))\(unit)"
        }
    }

    private var scheduleSummary: String {
        switch habit.schedule {
        case .daily: return "Every day"
        case .specificWeekdays: return "On selected days"
        case .everyNDays: return "Every \(max(habit.intervalDays, 1)) days"
        case .timesPerWeek: return "\(max(habit.weeklyTarget, 1))× per week"
        }
    }

    // MARK: - Stats

    private var stats: HabitStats { HabitStats(habit: habit) }
}

/// Value type computing streak and completion figures from a habit's logs.
private struct HabitStats {
    let currentStreak: Int
    let bestStreak: Int
    let totalCompleted: Int
    let last30Percent: Int

    init(habit: Habit, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: Date())

        // Distinct completed days (start-of-day), sorted ascending.
        var completedSet = Set<Date>()
        for log in habit.logs ?? [] where habit.isCompleted(on: log.day, calendar: calendar) {
            completedSet.insert(calendar.startOfDay(for: log.day))
        }
        let completed = completedSet.sorted()
        totalCompleted = completed.count

        // Current streak: walk back from today (or yesterday, if today is pending).
        var streak = 0
        var cursor = today
        if !completedSet.contains(today) {
            cursor = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        }
        while completedSet.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        currentStreak = streak

        // Best streak: longest run of consecutive completed days.
        var best = 0
        var run = 0
        var expected: Date?
        for day in completed {
            if let expected, expected == day {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            expected = calendar.date(byAdding: .day, value: 1, to: day)
        }
        bestStreak = best

        // Completion rate over the trailing 30 days.
        var last30 = 0
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            if completedSet.contains(day) { last30 += 1 }
        }
        last30Percent = Int((Double(last30) / 30.0 * 100).rounded())
    }
}

#Preview {
    NavigationStack {
        HabitDetailView(habit: Habit(name: "Read", emoji: "📚", colorHex: Cyberdream.habitPaletteHex[0]))
    }
    .preferredColorScheme(.dark)
}
