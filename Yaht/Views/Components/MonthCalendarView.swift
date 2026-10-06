import SwiftUI

/// A month of days for one habit, starting on the user's first weekday. Done
/// days are filled with the habit's color, partly done count days are tinted,
/// and today is outlined until it is done. Arrows step through earlier months.
struct MonthCalendarView: View {
    let habit: Habit
    @State private var monthOffset = 0

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let month = calendar.date(byAdding: .month, value: monthOffset, to: today) ?? today
        let cells = Self.cells(for: month, calendar: calendar)
        let symbols = Self.weekdaySymbols(calendar: calendar)

        VStack(spacing: 14) {
            HStack {
                Text(month, format: .dateTime.month(.wide).year())
                    .font(.rounded(17))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                monthButton("chevron.left", label: "Previous month") { monthOffset -= 1 }
                monthButton("chevron.right", label: "Next month") { monthOffset += 1 }
                    .disabled(monthOffset >= 0)
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
        let isFuture = date > today
        let isBeforeStart = date < calendar.startOfDay(for: habit.createdAt)
        let progress = isFuture ? 0 : habit.progress(on: date, calendar: calendar)
        let isDone = progress >= 1
        let isToday = calendar.isDate(date, inSameDayAs: today)
        let textColor: Color = isDone ? Theme.onAccent : (isFuture || isBeforeStart ? Theme.textDisabled : Theme.textPrimary)
        return Text(date, format: .dateTime.day())
            .font(.rounded(14, weight: isDone || isToday ? .heavy : .semibold))
            .monospacedDigit()
            .foregroundStyle(textColor)
            .frame(width: 36, height: 36)
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
            .accessibilityValue(isDone ? Text("Done") : (progress > 0 ? Text("Partly done") : Text("Not done")))
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
