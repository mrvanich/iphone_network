import Foundation

struct ScanRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    let date: Date
    let network: String
    let devices: [NetworkDevice]

    var cameraCount: Int { devices.filter { $0.kind.isCamera }.count }
}

struct ScanDiff {
    let added: [NetworkDevice]
    let removed: [NetworkDevice]
}

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [ScanRecord] = []
    private let key = "scanHistory.v1"

    init() { load() }

    func add(network: String, devices: [NetworkDevice]) {
        records.insert(ScanRecord(date: Date(), network: network, devices: devices), at: 0)
        if records.count > 50 { records = Array(records.prefix(50)) }
        save()
    }

    func clear() {
        records = []
        save()
    }

    /// Порівняння зі попереднім скануванням тієї ж мережі.
    func diff(for record: ScanRecord) -> ScanDiff? {
        guard let idx = records.firstIndex(where: { $0.id == record.id }) else { return nil }
        guard let previous = records[(idx + 1)...].first(where: { $0.network == record.network }) else { return nil }
        let before = Set(previous.devices.map { $0.ipValue })
        let now = Set(record.devices.map { $0.ipValue })
        return ScanDiff(added: record.devices.filter { !before.contains($0.ipValue) },
                        removed: previous.devices.filter { !now.contains($0.ipValue) })
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ScanRecord].self, from: data) else { return }
        records = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
