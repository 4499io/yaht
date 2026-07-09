import SwiftData
import SwiftUI

/// App home: a scrolling list of active habits with a global activity grid
/// header. Rows tap through to detail; a per-row control completes / increments
/// today. The toolbar "+" presents the habit editor as a sheet.
struct HabitListView: View {
    @Environment(HabitStore.self) private var store
    @Query(
        filter: #Predicate<Habit> { !$0.isArchived },
        sort: \Habit.sortOrder
    )
    private var habits: [Habit]

    @State private var showingEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            YahtWordmark()
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 12)

            Group {
                if habits.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditor = true
                } label: {
                    Label("Add Habit", systemImage: "plus")
                }
                .accessibilityIdentifier("habit-list-add-button")
            }
        }
        .sheet(isPresented: $showingEditor) {
            HabitEditView(habit: nil)
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                GlobalActivityGridView(habits: habits)
                    .accessibilityIdentifier("global-activity-grid")

                ForEach(habits) { habit in
                    HabitRowView(habit: habit, day: Date())
                }
            }
            .padding(16)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Habits Yet", systemImage: "checklist")
        } description: {
            Text("Create your first habit to start tracking.")
        } actions: {
            Button("New Habit") {
                showingEditor = true
            }
            .buttonStyle(.glass)
            .accessibilityIdentifier("habit-list-empty-add-button")
        }
    }
}

#Preview {
    NavigationStack {
        HabitListView()
    }
    .preferredColorScheme(.dark)
}
