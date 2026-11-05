import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = NetworkScanner()
    @State private var filter: Filter = .all
    @State private var sweep: Double = 0
    @Environment(\.openURL) private var openURL

    enum Filter: String, CaseIterable, Identifiable {
        case all = "Усі"
        case cameras = "Камери"
        var id: String { rawValue }
    }

    private var cameras: [NetworkDevice] { scanner.devices.filter { $0.kind.isCamera } }
    private var visible: [NetworkDevice] { filter == .cameras ? cameras : scanner.devices }

    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(spacing: 20) {
                    header
                    radar
                    stats
                    Picker("Фільтр", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if visible.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(visible) { device in
                                DeviceCard(device: device)
                                    .onTapGesture {
                                        if let url = URL(string: "http://\(device.ip)") { openURL(url) }
                                    }
                                    .contextMenu {
                                        Button("Копіювати IP", systemImage: "doc.on.doc") {
                                            UIPasteboard.general.string = device.ip
                                        }
                                        if let mac = device.mac {
                                            Button("Копіювати MAC", systemImage: "number") {
                                                UIPasteboard.general.string = mac
                                            }
                                        }
                                    }
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: visible)
                    }
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            VStack {
                Spacer()
                scanButton
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: scanner.isScanning) { scanning in
            if scanning {
                sweep = 0
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) { sweep = 360 }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                withAnimation(.linear(duration: 0.01)) { sweep = 0 }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    // MARK: - Частини

    private var background: some View {
        LinearGradient(colors: [Color(red: 0.04, green: 0.07, blue: 0.16),
                                Color(red: 0.06, green: 0.02, blue: 0.20)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Network Scanner")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.cyan, .blue, .purple],
                                                startPoint: .leading, endPoint: .trailing))
            if let net = scanner.network {
                Label("\(net.cidr) · \(net.ipString)", systemImage: "wifi")
                    .font(.system(.footnote, design: .monospaced))
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .foregroundColor(.white.opacity(0.8))
            }
            if let error = scanner.errorMessage {
                Text(error).font(.footnote).foregroundColor(.red).multilineTextAlignment(.center)
            }
        }
        .padding(.top, 12)
    }

    private var radar: some View {
        VStack(spacing: 10) {
            ZStack {
                ForEach(1..<4) { i in
                    Circle()
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                        .scaleEffect(CGFloat(i) / 3)
                }
                Circle()
                    .fill(AngularGradient(gradient: Gradient(colors: [.clear, .cyan.opacity(0.55)]),
                                          center: .center))
                    .opacity(scanner.isScanning ? 1 : 0)
                    .rotationEffect(.degrees(sweep))
                Circle()
                    .fill(Color.black.opacity(0.35))
                    .frame(width: 92, height: 92)
                    .overlay(Circle().stroke(Color.cyan.opacity(0.5), lineWidth: 1.5))
                VStack(spacing: 0) {
                    Text("\(scanner.devices.count)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("пристроїв").font(.caption2).foregroundColor(.white.opacity(0.6))
                }
            }
            .frame(width: 190, height: 190)

            if scanner.isScanning {
                ProgressView(value: scanner.progress).tint(.cyan).frame(maxWidth: 220)
            }
            Text(scanner.phase.isEmpty ? "Готовий до сканування" : scanner.phase)
                .font(.footnote).foregroundColor(.white.opacity(0.6))
        }
    }

    private var stats: some View {
        HStack(spacing: 10) {
            StatTile(title: "Камери", value: cameras.count, color: .red, icon: "video.fill")
            StatTile(title: "Hikvision", value: scanner.devices.filter { $0.kind == .hikvision }.count,
                     color: .orange, icon: "shield.fill")
            StatTile(title: "Dahua", value: scanner.devices.filter { $0.kind == .dahua }.count,
                     color: .yellow, icon: "dot.radiowaves.left.and.right")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 34)).foregroundColor(.cyan.opacity(0.7))
            Text(scanner.devices.isEmpty ? "Поки нічого не знайдено" : "Камер не знайдено")
                .font(.headline)
            Text("При першому запуску iOS попросить доступ до локальної мережі. Дозвольте і запустіть сканування ще раз.")
                .font(.footnote).foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24).padding(.horizontal, 12)
    }

    private var scanButton: some View {
        Button {
            scanner.isScanning ? scanner.stop() : scanner.start()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: scanner.isScanning ? "stop.fill" : "magnifyingglass")
                Text(scanner.isScanning ? "Зупинити" : "Сканувати мережу")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule().fill(LinearGradient(
                    colors: scanner.isScanning ? [.red, .pink] : [.cyan, .blue, .purple],
                    startPoint: .leading, endPoint: .trailing))
            )
            .shadow(color: (scanner.isScanning ? Color.red : Color.blue).opacity(0.5), radius: 14, y: 6)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

// MARK: - Картка статистики

private struct StatTile: View {
    let title: String
    let value: Int
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(color)
            Text("\(value)").font(.system(size: 24, weight: .bold, design: .rounded))
            Text(title).font(.caption2).foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Картка пристрою

private struct DeviceCard: View {
    let device: NetworkDevice

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(device.kind.color.opacity(0.2)).frame(width: 46, height: 46)
                Image(systemName: device.kind.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(device.kind.color)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(device.model).font(.headline).lineLimit(1)
                    Spacer(minLength: 6)
                    if let vendor = device.vendor {
                        Text(vendor)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(device.kind.color.opacity(0.2)))
                            .foregroundColor(device.kind.color)
                    }
                }
                Text(device.ip)
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .foregroundColor(.cyan)
                Text("MAC: \(device.mac ?? "недоступний")")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                if !device.openPorts.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(device.openPorts, id: \.self) { port in
                            Text(String(port))
                                .font(.system(.caption2, design: .monospaced))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)))
                        }
                    }
                }
                if let detail = device.detail {
                    Text(detail).font(.caption2).foregroundColor(.white.opacity(0.4)).lineLimit(1)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .stroke(device.kind.isCamera ? device.kind.color.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 18))
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
