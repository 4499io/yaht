import SwiftUI

/// Root screen. Hosts the habit list inside the app's single navigation stack.
///
/// `phoneWidthConstrained()` at the window root keeps the layout iPhone-width and
/// centered in resizable iPad windows (Guideline 4 — see 99issues #418). Sheets
/// present at window level, so each one applies the same cap on its own root.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            HabitListView()
        }
        .phoneWidthConstrained()
    }
}

#Preview {
    ContentView()
}
