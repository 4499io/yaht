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

    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3

    init(habit: Habit, weeks: Int = 20) {
        self.habit = habit
        self.columns = ActivityGridView.buildColumns(weeks: max(1, weeks), createdAt: habit.createdAt)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: cellSpacing) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: cellSpacing) {
                        ForEach(week) { cell in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(fill(for: cell))
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement()
        .accessibilityLabel("Activity grid")
        .accessibilityIdentifier("activity-grid-\(habit.id.uuidString)")
    }

    /// Map a cell to its fill color: faint for out-of-range or empty live days,
    /// scaling up to the full habit color at complete progress.
    private func fill(for cell: DayCell) -> Color {
        guard cell.isLive else { return Cyberdream.surface.opacity(0.35) }
        let progress = habit.progress(on: cell.date)
        guard progress > 0 else { return Cyberdream.elevated }
        return habit.color.opacity(0.3 + 0.7 * progress)
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
