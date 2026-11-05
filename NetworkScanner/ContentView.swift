import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = NetworkScanner()
    @State private var camerasOnly = false
    @Environment(\.openURL) private var openURL

    private var cameras: [NetworkDevice] { scanner.devices.filter { $0.kind.isCamera } }
    private var others: [NetworkDevice] { camerasOnly ? [] : scanner.devices.filter { !$0.kind.isCamera } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statusHeader
                List {
                    if !cameras.isEmpty {
                        Section("Камери та реєстратори (\(cameras.count))") {
                            ForEach(cameras) { row($0) }
                        }
                    }
                    if !others.isEmpty {
                        Section("Інші пристрої (\(others.count))") {
                            ForEach(others) { row($0) }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .overlay { if scanner.devices.isEmpty && !scanner.isScanning { emptyState } }

                scanButton
            }
            .navigationTitle("Network Scanner")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Toggle(isOn: $camerasOnly) { Image(systemName: "video") }
                        .toggleStyle(.button)
                }
            }
        }
    }

    // MARK: - Частини інтерфейсу

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let net = scanner.network {
                Text("Мережа \(net.cidr) · ваш IP \(net.ipString)")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            if scanner.isScanning {
                ProgressView(value: scanner.progress)
            }
            if !scanner.phase.isEmpty {
                Text(scanner.phase).font(.subheadline).foregroundColor(.secondary)
            }
            if let error = scanner.errorMessage {
                Text(error).font(.subheadline).foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "network").font(.largeTitle).foregroundColor(.secondary)
            Text("Натисніть «Сканувати мережу»")
                .font(.headline)
            Text("Під час першого запуску iOS запитає дозвіл на доступ до локальної мережі. Натисніть «Дозволити» і запустіть сканування ще раз.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var scanButton: some View {
        Button {
            scanner.isScanning ? scanner.stop() : scanner.start()
        } label: {
            Text(scanner.isScanning ? "Зупинити" : "Сканувати мережу")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(scanner.isScanning ? Color.red : Color.blue)
                .cornerRadius(12)
        }
        .padding()
    }

    private func row(_ d: NetworkDevice) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: d.kind.symbol).foregroundColor(d.kind.color)
                Text(d.model).font(.headline).lineLimit(1)
                Spacer()
                Text(d.ip)
                    .font(.system(.subheadline, design: .monospaced))
                    .bold()
                    .foregroundColor(.blue)
            }
            HStack {
                Text("MAC: \(d.mac ?? "недоступний")")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                if let vendor = d.vendor {
                    Text(vendor)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(d.kind.color.opacity(0.15))
                        .foregroundColor(d.kind.color)
                        .cornerRadius(6)
                }
            }
            if !d.openPorts.isEmpty {
                Text("Порти: " + d.openPorts.map(String.init).joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let detail = d.detail {
                Text(detail).font(.caption2).foregroundColor(.secondary).lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = URL(string: "http://\(d.ip)") { openURL(url) }
        }
        .contextMenu {
            Button("Копіювати IP") { UIPasteboard.general.string = d.ip }
            if let mac = d.mac {
                Button("Копіювати MAC") { UIPasteboard.general.string = mac }
            }
        }
    }
}

private extension DeviceKind {
    var symbol: String {
        switch self {
        case .hikvision, .dahua, .camera: return "video.fill"
        case .other: return "desktopcomputer"
        }
    }

    var color: Color {
        switch self {
        case .hikvision: return .red
        case .dahua: return .orange
        case .camera: return .purple
        case .other: return .blue
        }
    }
}
