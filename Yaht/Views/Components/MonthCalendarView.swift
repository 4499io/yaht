import SwiftUI

/// A month of days for one habit, starting on the user's first weekday. Done
/// days are filled with the habit's color, partly done count days are tinted,
/// and today is outlined until it is done. Arrows step through earlier months.
struct MonthCalendarView: View {
    @ScaledMetric(relativeTo: .caption) private var daySize: CGFloat = 36
    let habit: Habit
    @State private var monthOffset = 0

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let month = calendar.date(byAdding: .month, value: monthOffset, to: today) ?? today
        let cells = Self.cells(for: month, calendar: calendar)
        let symbols = Self.weekdaySymbols(calendar: calendar)

        VStack(spacing: 14) {
            AdaptiveStack(spacing: 8) {
                Text(month, format: .dateTime.month(.wide).year())
                    .roundedFont(17)
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 0) {
                monthButton("chevron.left", label: "Previous month") { monthOffset -= 1 }
                monthButton("chevron.right", label: "Next month") { monthOffset += 1 }
                    .disabled(monthOffset >= 0)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 8) {
                ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .accessibilityHidden(true)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date, today: today, calendar: calendar)
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }
            Text("Solid circles reached your goal. The outline marks today when its goal is still open.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func monthButton(_ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .frame(width: 36, height: 36)
                .background(Theme.raised, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.textPrimary)
        .accessibilityLabel(label)
    }

    private func dayCell(_ date: Date, today: Date, calendar: Calendar) -> some View {
        let status = CalendarDayStatus(habit: habit, date: date, today: today, calendar: calendar)
        let isFuture = date > today
        let isBeforeStart = date < calendar.startOfDay(for: habit.createdAt)
        let progress = isFuture ? 0 : habit.progress(on: date, calendar: calendar)
        let isDone = progress >= 1
        let isToday = calendar.isDate(date, inSameDayAs: today)
        let textColor: Color = isDone ? Theme.onAccent(habit.colorHex) : (isFuture || isBeforeStart ? Theme.textDisabled : Theme.textPrimary)
        return Text(date, format: .dateTime.day())
            .font(.system(size: min(daySize * 14 / 36, 24), weight: isDone || isToday ? .heavy : .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(textColor)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background {
                if isDone {
                    Circle().fill(habit.color)
                } else if progress > 0 {
                    Circle().fill(habit.color.opacity(0.3))
                }
            }
            .overlay {
                if isToday && !isDone {
                    Circle().strokeBorder(habit.color, lineWidth: 2)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(date, format: .dateTime.weekday(.wide).day().month(.wide)))
            .accessibilityValue(Text(status.label))
    }

    /// Leading blanks to align the 1st under its weekday, then every day.
    private static func cells(for month: Date, calendar: Calendar) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: leading)
        var day = interval.start
        while day < interval.end {
            result.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    /// Very short weekday symbols, starting on the user's first weekday.
    private static func weekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }
}
