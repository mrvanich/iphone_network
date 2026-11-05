import SwiftUI

struct ExternalIPView: View {
    @StateObject private var loader = ExternalIPLoader()
    @State private var copied = false

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 16) {
                    Text("Мій зовнішній IP")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.cyan, .blue, .purple],
                                                        startPoint: .leading, endPoint: .trailing))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ipCard
                    if let hint = loader.info?.relayHint { warning(hint) }
                    if let info = loader.info { detailsCard(info) }
                    if let error = loader.errorText {
                        Text(error).font(.footnote).foregroundColor(.red).multilineTextAlignment(.center)
                    }
                    refreshButton
                }
                .padding(16)
            }
            .refreshable { await loader.load() }
        }
        .task { await loader.load() }
    }

    private var ipCard: some View {
        Card {
            VStack(spacing: 10) {
                Image(systemName: "globe").font(.system(size: 34)).foregroundColor(.cyan)
                if loader.isLoading && loader.info == nil {
                    ProgressView().tint(.cyan)
                } else {
                    Text(loader.info?.ip ?? "—")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .minimumScaleFactor(0.5).lineLimit(1)
                        .textSelection(.enabled)
                }
                if let t = loader.updatedAt {
                    Text("Оновлено \(t.formatted(date: .omitted, time: .standard))")
                        .font(.caption2).foregroundColor(.white.opacity(0.45))
                }
                if let ip = loader.info?.ip {
                    Button {
                        UIPasteboard.general.string = ip
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    } label: {
                        Label(copied ? "Скопійовано" : "Копіювати", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func detailsCard(_ info: ExternalIPInfo) -> some View {
        Card {
            SectionTitle(text: "Деталі", icon: "mappin.and.ellipse")
            InfoRow(label: "Країна", value: info.countryName.map { "\(info.flag) \($0)" }, mono: false)
            InfoRow(label: "Регіон", value: info.region, mono: false)
            InfoRow(label: "Місто", value: info.city, mono: false)
            InfoRow(label: "Провайдер", value: info.org, mono: false)
            InfoRow(label: "Часовий пояс", value: info.timezone, mono: false)
            InfoRow(label: "Hostname", value: info.hostname)
        }
    }

    private func warning(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            Text(text).font(.footnote)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange.opacity(0.15)))
    }

    private var refreshButton: some View {
        Button {
            Task { await loader.load() }
        } label: {
            HStack {
                if loader.isLoading { ProgressView().tint(.white) } else { Image(systemName: "arrow.clockwise") }
                Text("Оновити")
            }
            .font(.headline).foregroundColor(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Capsule().fill(LinearGradient(colors: [.cyan, .blue, .purple],
                                                      startPoint: .leading, endPoint: .trailing)))
        }
        .disabled(loader.isLoading)
    }
}
