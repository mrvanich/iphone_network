import Foundation

struct ExternalIPInfo: Decodable {
    let ip: String
    var hostname: String?
    var city: String?
    var region: String?
    var country: String?
    var org: String?
    var timezone: String?

    var countryName: String? {
        guard let country else { return nil }
        return Locale(identifier: "uk").localizedString(forRegionCode: country) ?? country
    }

    var flag: String {
        guard let country else { return "" }
        return country.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(127397 + $0.value) }
            .map { String($0) }.joined()
    }

    /// Підказка, якщо схоже, що трафік іде через iCloud Private Relay.
    var relayHint: String? {
        let o = (org ?? "").lowercased()
        if o.contains("apple") { return "Схоже, увімкнено iCloud Private Relay — це не ваша справжня адреса." }
        if o.contains("akamai") || o.contains("cloudflare") || o.contains("fastly") {
            return "Можливо, увімкнено iCloud Private Relay або це CDN-провайдер."
        }
        return nil
    }
}

@MainActor
final class ExternalIPLoader: ObservableObject {
    @Published private(set) var info: ExternalIPInfo?
    @Published private(set) var isLoading = false
    @Published private(set) var errorText: String?
    @Published private(set) var updatedAt: Date?

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            info = try await Self.fetchInfo()
        } catch {
            do {
                info = try await Self.fetchPlain()
            } catch {
                errorText = "Не вдалося отримати зовнішній IP. Перевірте інтернет-з'єднання."
            }
        }
        if info != nil { updatedAt = Date() }
    }

    private static func get(_ urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    private static func fetchInfo() async throws -> ExternalIPInfo {
        try JSONDecoder().decode(ExternalIPInfo.self, from: try await get("https://ipinfo.io/json"))
    }

    private static func fetchPlain() async throws -> ExternalIPInfo {
        try JSONDecoder().decode(ExternalIPInfo.self, from: try await get("https://api.ipify.org?format=json"))
    }
}
