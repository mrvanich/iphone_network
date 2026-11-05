import SwiftUI

struct NetworkInfoView: View {
    @StateObject private var status = NetworkStatus()

    private let steps = [
        "Налаштування → Wi-Fi → натисніть (i) біля вашої мережі.",
        "«Приватна адреса Wi-Fi» → вимкнути (для постійного MAC).",
        "«Обмеження відстеження IP-адреси» → вимкнути.",
        "Налаштування → [ваше ім'я] → iCloud → Приватна передача (Private Relay) → вимкнути.",
        "Справжній MAC iPhone дивіться там же: Налаштування → Wi-Fi → (i) → «Адреса Wi-Fi»."
    ]

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 16) {
                    Text("Моя мережа")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.cyan, .blue, .purple],
                                                        startPoint: .leading, endPoint: .trailing))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    connectionCard
                    detailsCard
                    privacyCard
                }
                .padding(16)
            }
            .refreshable { status.refresh() }
        }
        .onAppear { status.start() }
    }

    private var connectionCard: some View {
        Card {
            HStack(spacing: 14) {
                Image(systemName: status.info.connection == "Wi-Fi" ? "wifi" :
                        (status.info.connection == "Мобільна мережа" ? "antenna.radiowaves.left.and.right" : "network"))
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.cyan)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.cyan.opacity(0.15)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(status.info.connection).font(.title3.weight(.bold))
                    HStack(spacing: 6) {
                        if status.info.isExpensive { chip("Платний трафік") }
                        if status.info.isConstrained { chip("Економія даних") }
                    }
                }
                Spacer()
            }
        }
    }

    private var detailsCard: some View {
        Card {
            SectionTitle(text: "Wi-Fi (IPv4)", icon: "list.bullet.rectangle")
            if status.info.hasWiFi {
                InfoRow(label: "IP iPhone", value: status.info.ip)
                InfoRow(label: "Маска", value: status.info.mask)
                InfoRow(label: "Підмережа", value: status.info.cidr)
                InfoRow(label: "Шлюз (роутер)", value: status.info.gateway)
                InfoRow(label: "Діапазон хостів",
                        value: status.info.firstHost.flatMap { f in status.info.lastHost.map { "\(f) – \($0)" } })
                InfoRow(label: "Broadcast", value: status.info.broadcast)
                ForEach(status.info.ipv6, id: \.self) { InfoRow(label: "IPv6", value: $0) }
            } else {
                Text("iPhone не підключений до Wi-Fi.")
                    .font(.subheadline).foregroundColor(.white.opacity(0.6))
            }
            if let cell = status.info.cellularIP {
                Divider().overlay(Color.white.opacity(0.1))
                InfoRow(label: "Мобільний IP", value: cell)
            }
        }
    }

    private var privacyCard: some View {
        Card {
            SectionTitle(text: "Випадковий MAC і відстеження", icon: "lock.shield")
            Text("iOS не дозволяє застосункам змінювати ці налаштування — їх можна вимкнути тільки вручну в Налаштуваннях, для кожної мережі окремо.")
                .font(.footnote).foregroundColor(.white.opacity(0.65))
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, text in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(idx + 1)")
                            .font(.caption.weight(.bold))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.cyan.opacity(0.25)))
                        Text(text).font(.subheadline)
                    }
                }
            }
            Button {
                openWiFiSettings()
            } label: {
                Label("Відкрити Налаштування", systemImage: "gearshape.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(LinearGradient(colors: [.cyan, .blue],
                                                              startPoint: .leading, endPoint: .trailing)))
                    .foregroundColor(.white)
            }
            Text("iOS може відкрити лише головну сторінку Налаштувань — далі шлях Wi-Fi → (i).")
                .font(.caption2).foregroundColor(.white.opacity(0.45))
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(Color.orange.opacity(0.25)))
            .foregroundColor(.orange)
    }

    private func openWiFiSettings() {
        let fallback = {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
        if let url = URL(string: "App-Prefs:root=WIFI") {
            UIApplication.shared.open(url, options: [:]) { ok in if !ok { fallback() } }
        } else {
            fallback()
        }
    }
}
