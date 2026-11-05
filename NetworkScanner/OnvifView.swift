import SwiftUI

struct OnvifResult {
    enum Status { case full, partial, none }
    var status: Status
    var manufacturer: String? = nil
    var model: String? = nil
    var firmware: String? = nil
    var serial: String? = nil
    var port: UInt16? = nil
}

private let onvifPorts: Set<UInt16> = [80, 8080, 8899, 2020]

private let infoBody = """
<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"><s:Body xmlns:tds="http://www.onvif.org/ver10/device/wsdl"><tds:GetDeviceInformation/></s:Body></s:Envelope>
"""

private let timeBody = """
<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"><s:Body xmlns:tds="http://www.onvif.org/ver10/device/wsdl"><tds:GetSystemDateAndTime/></s:Body></s:Envelope>
"""

private func xmlTag(_ name: String, in s: String) -> String? {
    let pattern = "<(?:[A-Za-z0-9]+:)?\(name)>([^<]*)</(?:[A-Za-z0-9]+:)?\(name)>"
    guard let re = try? NSRegularExpression(pattern: pattern),
          let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
          let r = Range(m.range(at: 1), in: s) else { return nil }
    let v = String(s[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    return v.isEmpty ? nil : v
}

@MainActor
final class OnvifChecker: ObservableObject {
    @Published private(set) var results: [UInt32: OnvifResult] = [:]
    @Published private(set) var isRunning = false
    @Published private(set) var done = 0
    @Published private(set) var total = 0

    func run(devices: [NetworkDevice]) async {
        guard !isRunning else { return }
        let candidates = devices.filter { !Set($0.openPorts).isDisjoint(with: onvifPorts) }
        results = [:]
        done = 0
        total = candidates.count
        isRunning = true
        await withTaskGroup(of: (UInt32, OnvifResult).self) { group in
            for d in candidates {
                group.addTask { (d.ipValue, await Self.probe(d)) }
            }
            for await (ip, result) in group {
                results[ip] = result
                done += 1
            }
        }
        isRunning = false
    }

    nonisolated private static func probe(_ d: NetworkDevice) async -> OnvifResult {
        let ct = "application/soap+xml; charset=utf-8"
        for port in d.openPorts where onvifPorts.contains(port) {
            if let r = await Net.httpPost(ip: d.ipValue, port: port, path: "/onvif/device_service",
                                          body: infoBody, contentType: ct) {
                if let manufacturer = xmlTag("Manufacturer", in: r) {
                    return OnvifResult(status: .full, manufacturer: manufacturer,
                                       model: xmlTag("Model", in: r),
                                       firmware: xmlTag("FirmwareVersion", in: r),
                                       serial: xmlTag("SerialNumber", in: r), port: port)
                }
                if r.contains("Envelope") || r.localizedCaseInsensitiveContains("onvif") {
                    return OnvifResult(status: .partial, port: port)
                }
            }
            if let t = await Net.httpPost(ip: d.ipValue, port: port, path: "/onvif/device_service",
                                          body: timeBody, contentType: ct),
               t.contains("SystemDateAndTime") {
                return OnvifResult(status: .partial, port: port)
            }
        }
        return OnvifResult(status: .none)
    }
}

struct OnvifView: View {
    @EnvironmentObject private var scanner: NetworkScanner
    @StateObject private var checker = OnvifChecker()

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 14) {
                    Card {
                        SectionTitle(text: "Перевірка ONVIF", icon: "checkmark.seal")
                        Text("ONVIF — стандарт IP-камер. Застосунок перевіряє знайдені пристрої й, якщо камера відповідає без логіна, показує виробника, модель, прошивку та серійний номер.")
                            .font(.footnote).foregroundColor(.white.opacity(0.65))
                        Text("Мультикаст-пошук (WS-Discovery) на iOS потребує спеціального дозволу Apple, тому перевіряються пристрої з вкладки «Сканер».")
                            .font(.caption2).foregroundColor(.white.opacity(0.45))
                        Button {
                            Task { await checker.run(devices: scanner.devices) }
                        } label: {
                            HStack {
                                if checker.isRunning { ProgressView().tint(.white) }
                                else { Image(systemName: "play.fill") }
                                Text(checker.isRunning ? "Перевірка \(checker.done)/\(checker.total)…" : "Перевірити знайдені пристрої")
                            }
                            .font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Capsule().fill(LinearGradient(colors: [.cyan, .blue, .purple],
                                                                      startPoint: .leading, endPoint: .trailing)))
                        }
                        .disabled(checker.isRunning || scanner.devices.isEmpty)
                        if scanner.devices.isEmpty {
                            Text("Спочатку запустіть сканування на вкладці «Сканер».")
                                .font(.caption).foregroundColor(.orange)
                        }
                    }

                    ForEach(scanner.devices.filter { checker.results[$0.ipValue] != nil }) { d in
                        if let r = checker.results[d.ipValue] { resultCard(d, r) }
                    }
                    SiteFooter()
                }
                .padding(16)
            }
        }
        .navigationTitle("ONVIF")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func resultCard(_ d: NetworkDevice, _ r: OnvifResult) -> some View {
        Card {
            HStack {
                Text(d.ip).font(.system(.headline, design: .monospaced)).foregroundColor(.cyan)
                Spacer()
                switch r.status {
                case .full: Chip(text: "ONVIF ✓", color: .green)
                case .partial: Chip(text: "ONVIF · потрібен логін", color: .orange)
                case .none: Chip(text: "Немає ONVIF", color: .gray)
                }
            }
            if r.status == .full {
                InfoRow(label: "Виробник", value: r.manufacturer, mono: false)
                InfoRow(label: "Модель", value: r.model, mono: false)
                InfoRow(label: "Прошивка", value: r.firmware)
                InfoRow(label: "Серійний №", value: r.serial)
            }
            if let port = r.port { InfoRow(label: "Порт", value: String(port)) }
        }
    }
}
