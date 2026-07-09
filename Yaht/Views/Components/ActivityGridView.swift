import SwiftUI

/// A GitHub-style contribution grid for a single habit. Columns are weeks
/// (oldest on the left, the current week on the right) and rows are the seven
/// weekdays (Sunday at the top). Each cell's fill is the habit's color at an
/// opacity derived from ``Habit/progress(on:calendar:)`` for that day.
///
/// The date layout is fixed at init (it depends only on `createdAt`/today), while
/// the per-cell progress is read at render time so the grid reacts to new logs.
struct ActivityGridView: View {
    private let habit: Habit
    private let columns: [[DayCell]]

    init(habit: Habit, weeks: Int = 20) {
        self.habit = habit
        self.columns = ActivityGridView.buildColumns(weeks: max(1, weeks), createdAt: habit.createdAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ActivityStyle.cellSpacing) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: ActivityStyle.cellSpacing) {
                            ForEach(week) { cell in
                                RoundedRectangle(cornerRadius: ActivityStyle.cornerRadius, style: .continuous)
                                    .fill(fill(for: cell))
                                    .frame(width: ActivityStyle.cellSize, height: ActivityStyle.cellSize)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .accessibilityElement()
            .accessibilityLabel("Activity grid")
            .accessibilityIdentifier("activity-grid-\(habit.id.uuidString)")
            legend
        }
    }

    /// Map a cell to its fill color: a faint ghost for out-of-range days, a clear
    /// empty lattice for live-but-incomplete days, scaling up to the solid habit
    /// color at full progress. Shared with the global grid via ``ActivityStyle``.
    private func fill(for cell: DayCell) -> Color {
        guard cell.isLive else { return ActivityStyle.ghostFill }
        let progress = habit.progress(on: cell.date)
        guard progress > 0 else { return ActivityStyle.emptyFill }
        return ActivityStyle.fill(habit.color, level: progress)
    }

    /// Intensity key, in this habit's own color, so the grid explains itself.
    private var legend: some View {
        HStack(spacing: ActivityStyle.cellSpacing) {
            Text("Less")
                .font(.caption2)
                .foregroundStyle(Cyberdream.textSecondary)
            ForEach(ActivityStyle.legendLevels, id: \.self) { level in
                RoundedRectangle(cornerRadius: ActivityStyle.cornerRadius, style: .continuous)
                    .fill(ActivityStyle.legendFill(habit.color, level: level))
                    .frame(width: ActivityStyle.cellSize, height: ActivityStyle.cellSize)
            }
            Text("More")
                .font(.caption2)
                .foregroundStyle(Cyberdream.textSecondary)
        }
    }

    /// One day in the grid. Identity is the day itself so `ForEach` stays stable.
    private struct DayCell: Identifiable {
        let date: Date
        let isLive: Bool
        var id: Date { date }
    }

    /// Build `weeks` columns of seven days each, aligned so the last column holds
    /// the current week and each row corresponds to a fixed weekday.
    private static func buildColumns(weeks: Int, createdAt: Date) -> [[DayCell]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let createdStart = calendar.startOfDay(for: createdAt)
        let weekday = calendar.component(.weekday, from: today) // 1 (Sun) ... 7 (Sat)
        guard let startOfCurrentWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: today) else {
            return []
        }

        var result: [[DayCell]] = []
        for column in 0..<weeks {
            let weekOffset = -(weeks - 1 - column)
            guard let columnStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startOfCurrentWeek) else {
                continue
            }
            var days: [DayCell] = []
            for row in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: row, to: columnStart) else { continue }
                let isLive = date >= createdStart && date <= today
                days.append(DayCell(date: date, isLive: isLive))
            }
            result.append(days)
        }
        return result
    }
}

#Preview {
    let habit = Habit(name: "Read", emoji: "📚", colorHex: Cyberdream.habitPaletteHex[0])
    return GlassCard {
        ActivityGridView(habit: habit)
    }
    .padding()
    .preferredColorScheme(.dark)
}
