import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NetworkInfoView()
                .tabItem { Label("Мережа", systemImage: "wifi") }
            ContentView()
                .tabItem { Label("Сканер", systemImage: "dot.radiowaves.left.and.right") }
            ExternalIPView()
                .tabItem { Label("Мій IP", systemImage: "globe") }
        }
        .tint(.cyan)
        .preferredColorScheme(.dark)
    }
}
