import Foundation

private struct Probe: Sendable {
    let ip: UInt32
    let port: UInt16
}

/// Ковзне вікно паралельних задач: не більше `limit` одночасно (iOS має ліміт на файлові дескриптори).
private func forEachConcurrent<T: Sendable, R: Sendable>(
    _ items: [T],
    limit: Int,
    work: @escaping @Sendable (T) async -> R,
    onResult: @MainActor (T, R) -> Void
) async {
    await withTaskGroup(of: (Int, R).self) { group in
        var next = 0
        while next < min(limit, items.count) {
            let i = next
            next += 1
            group.addTask { (i, await work(items[i])) }
        }
        while let (i, result) = await group.next() {
            await onResult(items[i], result)
            if Task.isCancelled {
                group.cancelAll()
            } else if next < items.count {
                let j = next
                next += 1
                group.addTask { (j, await work(items[j])) }
            }
        }
    }
}

@MainActor
final class NetworkScanner: ObservableObject {
    @Published private(set) var devices: [NetworkDevice] = []
    @Published private(set) var isScanning = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var phase = ""
    @Published private(set) var network: LocalNetwork?
    @Published private(set) var errorMessage: String?

    /// Порти, за якими розпізнаємо камери: HTTP, HTTPS, RTSP, Hikvision SDK, alt-HTTP, ONVIF, Dahua.
    private static let ports: [UInt16] = [80, 443, 554, 8000, 8080, 8899, 37777]
    private var task: Task<Void, Never>?
    var onFinished: (@MainActor ([NetworkDevice], String) -> Void)?

    func start() {
        guard !isScanning else { return }
        errorMessage = nil
        guard let net = LocalNetwork.current() else {
            errorMessage = "Не вдалося визначити Wi-Fi мережу. Підключіться до Wi-Fi і спробуйте ще раз."
            return
        }
        network = net
        devices = []
        progress = 0
        isScanning = true
        task = Task { await run(net) }
    }

    func loadNetwork() {
        if !isScanning { network = LocalNetwork.current() }
    }

    func stop() {
        task?.cancel()
    }

    private func run(_ net: LocalNetwork) async {
        let hosts = net.hostAddresses()
        let probes = hosts.flatMap { ip in Self.ports.map { Probe(ip: ip, port: $0) } }

        // 1. Сканування портів
        phase = "Перевірка портів (\(hosts.count) адрес)…"
        var openPorts: [UInt32: [UInt16]] = [:]
        var done = 0
        await forEachConcurrent(probes, limit: 128, work: { p in
            await Net.isPortOpen(ip: p.ip, port: p.port, timeout: 0.9)
        }, onResult: { p, isOpen in
            done += 1
            if isOpen { openPorts[p.ip, default: []].append(p.port) }
            if done % 16 == 0 { self.progress = Double(done) / Double(probes.count) * 0.8 }
        })

        // 2. Розпізнавання знайдених пристроїв
        phase = "Визначення типів пристроїв…"
        let snapshot = openPorts
        let responders = snapshot.keys.sorted()
        var found = 0
        await forEachConcurrent(responders, limit: 8, work: { ip in
            await Fingerprinter.identify(ip: ip, openPorts: (snapshot[ip] ?? []).sorted())
        }, onResult: { ip, fp in
            found += 1
            let device = NetworkDevice(ipValue: ip, mac: nil, vendor: fp.vendor, model: fp.model,
                                       kind: fp.kind, openPorts: (snapshot[ip] ?? []).sorted(), detail: fp.detail)
            self.insert(device)
            self.progress = 0.8 + 0.15 * Double(found) / Double(max(responders.count, 1))
        })

        // 3. MAC-адреси з ARP-кешу + виробник за OUI; додаємо хости без відкритих портів
        phase = "Читання MAC-адрес…"
        let arp = ARPTable.read()
        let known = Set(hosts)
        for (ip, _) in arp where known.contains(ip) && snapshot[ip] == nil {
            insert(NetworkDevice(ipValue: ip, mac: nil, vendor: nil, model: "Пристрій без відкритих портів",
                                 kind: .other, openPorts: [], detail: nil))
        }
        devices = devices.map { Self.enrich($0, mac: arp[$0.ipValue]) }

        progress = 1
        phase = Task.isCancelled ? "Зупинено" : "Готово: знайдено \(devices.count)"
        if !Task.isCancelled && !devices.isEmpty { onFinished?(devices, net.cidr) }
        isScanning = false
    }

    private func insert(_ d: NetworkDevice) {
        devices = (devices + [d]).sorted { $0.ipValue < $1.ipValue }
    }

    private static func enrich(_ d: NetworkDevice, mac: String?) -> NetworkDevice {
        var d = d
        d.mac = mac
        guard let mac, let oui = OUI.vendor(for: mac) else { return d }
        if d.vendor == nil { d.vendor = oui }
        if d.kind == .other || d.kind == .camera {
            if oui == "Hikvision" { d.kind = .hikvision }
            if oui == "Dahua" { d.kind = .dahua }
        }
        return d
    }
}
