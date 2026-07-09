import SwiftUI

/// The app's signature global progress view: a GitHub-style contribution grid
/// where each day cell blends the colors of every habit completed that day.
///
/// The blend is an equal-weight sRGB average of the completed habits' colors
/// (see ``blend(_:)``). A cell's opacity scales with how many of that day's *due*
/// habits were actually completed, so a fully-satisfied day reads at full strength
/// while a partial day is dimmer. Days with no completions render as a faint tint.
///
/// The per-day color/intensity map is precomputed once per render (in ``init``)
/// so the body stays cheap even across many weeks of history.
struct GlobalActivityGridView: View {
    private let weeks: Int
    private let cells: [DayCell]

    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 3
    private let legendSteps: [Double] = [0.08, 0.3, 0.5, 0.7, 1.0]

    /// One day's rendering data. `color == nil` means "no completions".
    private struct DayCell {
        let date: Date
        let color: Color?
        let intensity: Double
        let inRange: Bool
    }

    init(habits: [Habit], weeks: Int = 20) {
        let weekCount = max(weeks, 1)
        self.weeks = weekCount
        self.cells = Self.buildCells(habits: habits, weeks: weekCount, calendar: .current)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                header
                grid
                legend
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Activity")
                .font(.headline)
                .foregroundStyle(Cyberdream.textPrimary)
            Spacer()
            Text("\(weeks) weeks")
                .font(.caption)
                .foregroundStyle(Cyberdream.textSecondary)
        }
    }

    private var grid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(0..<weeks, id: \.self) { column in
                    VStack(spacing: cellSpacing) {
                        ForEach(0..<7, id: \.self) { row in
                            cellView(cells[column * 7 + row])
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityIdentifier("global-activity-grid")
    }

    private func cellView(_ cell: DayCell) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(fill(for: cell))
            .frame(width: cellSize, height: cellSize)
            .opacity(cell.inRange ? 1 : 0)
    }

    private func fill(for cell: DayCell) -> Color {
        guard let color = cell.color else {
            return Cyberdream.textSecondary.opacity(0.08)
        }
        return color.opacity(0.35 + cell.intensity * 0.65)
    }

    private var legend: some View {
        HStack(spacing: cellSpacing) {
            Text("Less")
                .font(.caption2)
                .foregroundStyle(Cyberdream.textSecondary)
            ForEach(legendSteps, id: \.self) { step in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Cyberdream.textSecondary.opacity(step))
                    .frame(width: cellSize, height: cellSize)
            }
            Text("More")
                .font(.caption2)
                .foregroundStyle(Cyberdream.textSecondary)
        }
    }

    /// Builds the ordered grid cells (column-major: one column per week, seven
    /// rows per column) from a single precomputed `[Date: (color, intensity)]` map.
    private static func buildCells(habits: [Habit], weeks: Int, calendar cal: Calendar) -> [DayCell] {
        let today = cal.startOfDay(for: Date())
        let weekStart = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let gridStart = cal.date(byAdding: .weekOfYear, value: -(weeks - 1), to: weekStart) ?? weekStart

        var dates: [Date] = []
        dates.reserveCapacity(weeks * 7)
        for offset in 0..<(weeks * 7) {
            dates.append(cal.date(byAdding: .day, value: offset, to: gridStart) ?? gridStart)
        }

        // Precompute the color + intensity for each active day exactly once.
        var map: [Date: (color: Color, intensity: Double)] = [:]
        for date in dates where date <= today {
            let day = cal.startOfDay(for: date)
            guard map[day] == nil else { continue }
            let completed = habits.filter { $0.isCompleted(on: day, calendar: cal) }
            guard !completed.isEmpty else { continue }

            let due = habits.filter { $0.isDue(on: day, calendar: cal) }
            let completedDue = due.filter { $0.isCompleted(on: day, calendar: cal) }.count
            let fraction = due.isEmpty ? 1.0 : Double(completedDue) / Double(due.count)
            let intensity = min(max(fraction, 0), 1)
            map[day] = (blend(completed.map(\.color)), intensity)
        }

        return dates.map { date in
            let inRange = date <= today
            let entry = inRange ? map[cal.startOfDay(for: date)] : nil
            return DayCell(date: date, color: entry?.color, intensity: entry?.intensity ?? 0, inRange: inRange)
        }
    }
}

#Preview("Global Activity") {
    let habits = (0..<4).map { index -> Habit in
        let habit = Habit()
        habit.colorHex = Cyberdream.habitPaletteHex[index]
        return habit
    }
    return GlobalActivityGridView(habits: habits)
        .padding()
        .preferredColorScheme(.dark)
}
