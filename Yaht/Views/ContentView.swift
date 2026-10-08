import SwiftUI
import SwiftData

/// Root screen. Hosts the habit list inside the app's single navigation stack.
///
/// `phoneWidthConstrained()` at the window root keeps the layout iPhone-width and
/// centered in resizable iPad windows (Guideline 4 — see 99issues #418). Sheets
/// present at window level, so each one applies the same cap on its own root.
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var habits: [Habit]
    @Query private var reminders: [Reminder]

    private struct ReconciliationKey: Equatable {
        let isActive: Bool
        let snapshots: [NotificationHabitSnapshot]
        let reminderIDs: [UUID]
    }

    var body: some View {
        let snapshots = habits.map { NotificationHabitSnapshot($0) }.sorted { $0.id.uuidString < $1.id.uuidString }
        let key = ReconciliationKey(
            isActive: scenePhase == .active,
            snapshots: snapshots,
            reminderIDs: reminders.map(\.id).sorted { $0.uuidString < $1.uuidString }
        )
        NavigationStack {
            HabitListView()
        }
        .phoneWidthConstrained()
        .background(Theme.background.ignoresSafeArea())
        .tint(Theme.tint)
        .task(id: key) {
            guard key.isActive else { return }
            _ = await NotificationScheduler.shared.requestAuthorization()
            guard !Task.isCancelled else { return }
            await NotificationScheduler.shared.reconcile(key.snapshots)
        }
    }
}

#Preview {
    ContentView()
}
