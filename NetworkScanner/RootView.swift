import SwiftUI

struct RootView: View {
    @StateObject private var scanner = NetworkScanner()
    @StateObject private var history = HistoryStore()

    var body: some View {
        TabView {
            NetworkInfoView()
                .tabItem { Label("Мережа", systemImage: "wifi") }
            ContentView()
                .tabItem { Label("Сканер", systemImage: "dot.radiowaves.left.and.right") }
            ExternalIPView()
                .tabItem { Label("Мій IP", systemImage: "globe") }
            AdditionalView()
                .tabItem { Label("Додатково", systemImage: "square.grid.2x2") }
        }
        .environmentObject(scanner)
        .environmentObject(history)
        .tint(.cyan)
        .preferredColorScheme(.dark)
        .onAppear {
            scanner.onFinished = { devices, network in
                history.add(network: network, devices: devices)
            }
        }
    }
}
