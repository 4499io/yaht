import SwiftUI

/// Placeholder root screen. Real habit UI arrives in a later step (see docs/PLAN.md).
/// Always-dark is enforced app-wide via INFOPLIST_KEY_UIUserInterfaceStyle = Dark.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("🧩")
                    .font(.system(size: 72))
                Text("Yaht")
                    .font(.largeTitle.bold())
                Text("yet another habit tracker")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Yaht")
        }
    }
}

#Preview {
    ContentView()
}
