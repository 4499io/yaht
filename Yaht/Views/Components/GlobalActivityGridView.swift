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
    private let checkIns: Int

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
        let built = Self.buildCells(habits: habits, weeks: weekCount, calendar: .current)
        self.cells = built.cells
        self.checkIns = built.checkIns
    }

    var body: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                header
                grid
                Text("Each square is a day. Brighter squares mean more habits completed.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var header: some View {
        AdaptiveStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your rhythm")
                    .roundedFont(17)
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Last \(weeks) weeks")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(checkIns) check-ins")
                .font(.footnote)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    /// Cells size themselves to the card's width (square, equal columns), so
    /// the grid fills the card edge to edge on every screen size.
    private var grid: some View {
        Grid(horizontalSpacing: ActivityStyle.cellSpacing, verticalSpacing: ActivityStyle.cellSpacing) {
            ForEach(0..<7, id: \.self) { row in
                GridRow {
                    ForEach(0..<weeks, id: \.self) { column in
                        cellView(cells[column * 7 + row])
                    }
                }
            }
            GridRow {
                ForEach(monthLabels) { month in
                    Text(month.title)
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // Too narrow to read when a month only touches 1–2 weeks.
                        .opacity(month.weeks >= 3 ? 1 : 0)
                        .padding(.top, 2)
                        .accessibilityHidden(true)
                        .gridCellColumns(month.weeks)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Activity, last \(weeks) weeks")
        .accessibilityValue("\(checkIns) check-ins")
        .accessibilityIdentifier("global-activity-grid")
    }

    private func cellView(_ cell: DayCell) -> some View {
        RoundedRectangle(cornerRadius: ActivityStyle.cornerRadius, style: .continuous)
            .fill(fill(for: cell))
            .aspectRatio(1, contentMode: .fit)
    }

    /// Runs of week columns by the month their first day falls in.
    private struct MonthLabel: Identifiable {
        let id: Int
        let title: String
        let weeks: Int
    }

    private var monthLabels: [MonthLabel] {
        let calendar = Calendar.current
        var labels: [MonthLabel] = []
        for column in 0..<weeks {
            let date = cells[column * 7].date
            let month = calendar.component(.month, from: date)
            if let last = labels.last, calendar.component(.month, from: cells[last.id * 7].date) == month {
                labels[labels.count - 1] = MonthLabel(id: last.id, title: last.title, weeks: last.weeks + 1)
            } else {
                labels.append(MonthLabel(id: column, title: date.formatted(.dateTime.month(.abbreviated)), weeks: 1))
            }
        }
        return labels
    }

    private func fill(for cell: DayCell) -> Color {
        guard cell.inRange else { return ActivityStyle.ghostFill }
        guard let color = cell.color else { return ActivityStyle.emptyFill }
        return ActivityStyle.fill(color, level: cell.intensity)
    }

    /// Builds the ordered grid cells (column-major: one column per week, seven
    /// rows per column) from a single precomputed `[Date: (color, intensity)]` map.
    private static func buildCells(
        habits: [Habit], weeks: Int, calendar cal: Calendar
    ) -> (cells: [DayCell], checkIns: Int) {
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
        var checkIns = 0
        for date in dates where date <= today {
            let day = cal.startOfDay(for: date)
            guard map[day] == nil else { continue }
            let completed = habits.filter { $0.isCompleted(on: day, calendar: cal) }
            guard !completed.isEmpty else { continue }
            checkIns += completed.count

            let due = habits.filter { $0.isDue(on: day, calendar: cal) }
            let completedDue = due.filter { $0.isCompleted(on: day, calendar: cal) }.count
            let fraction = due.isEmpty ? 1.0 : Double(completedDue) / Double(due.count)
            let intensity = min(max(fraction, 0), 1)
            map[day] = (blend(completed.map(\.color)), intensity)
        }

        let cells = dates.map { date in
            let inRange = date <= today
            let entry = inRange ? map[cal.startOfDay(for: date)] : nil
            return DayCell(date: date, color: entry?.color, intensity: entry?.intensity ?? 0, inRange: inRange)
        }
        return (cells, checkIns)
    }
}

#Preview("Global Activity") {
    let habits = (0..<4).map { index -> Habit in
        let habit = Habit()
        habit.colorHex = Theme.habitPaletteHex[index]
        return habit
    }
    return GlobalActivityGridView(habits: habits)
        .padding()
        .preferredColorScheme(.dark)
}
