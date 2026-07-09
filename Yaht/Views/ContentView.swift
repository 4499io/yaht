import SwiftUI

/// Root screen. Hosts the habit list inside the app's single navigation stack.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            HabitListView()
        }
    }
}

#Preview {
    ContentView()
}
