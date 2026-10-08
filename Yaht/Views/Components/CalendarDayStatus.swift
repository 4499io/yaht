import Foundation
import SwiftUI

/// History never treats future, unscheduled or pre-creation days as missed goals.
enum CalendarDayStatus: Equatable {
    case future, beforeStart, done, partial, paused, notScheduled, notDone

    init(habit: Habit, date: Date, today: Date, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: date)
        if day > calendar.startOfDay(for: today) { self = .future }
        else if day < calendar.startOfDay(for: habit.createdAt) { self = .beforeStart }
        else if habit.isCompleted(on: day, calendar: calendar) { self = .done }
        else if habit.progress(on: day, calendar: calendar) > 0 { self = .partial }
        else if habit.isPaused(on: day, calendar: calendar) { self = .paused }
        else if !habit.isDue(on: day, calendar: calendar) { self = .notScheduled }
        else { self = .notDone }
    }

    var label: LocalizedStringKey {
        switch self {
        case .future: "Future date"
        case .beforeStart: "Before this habit started"
        case .done: "Goal reached"
        case .partial: "Partly completed"
        case .paused: "Habit paused"
        case .notScheduled: "Not scheduled"
        case .notDone: "Not completed"
        }
    }
}
