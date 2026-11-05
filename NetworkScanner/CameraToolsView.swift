import SwiftUI

struct SnapError: Error {
    let message: String
    let isAuth: Bool
}

private final class AuthDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let user: String
    let pass: String
    init(user: String, pass: String) { self.user = user; self.pass = pass }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let method = challenge.protectionSpace.authenticationMethod
        guard challenge.previousFailureCount == 0,
              method == NSURLAuthenticationMethodHTTPBasic || method == NSURLAuthenticationMethodHTTPDigest else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(user: user, password: pass, persistence: .none))
    }
}

@MainActor
final class SnapshotLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var errorText: String?
    @Published private(set) var isLoading = false
    @Published private(set) var updatedAt: Date?

    func load(device: NetworkDevice, user: String, pass: String, channel: Int) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let port: Int = device.openPorts.contains(80) ? 80 : (device.openPorts.contains(8080) ? 8080 : 80)
        let base = port == 80 ? "http://\(device.ip)" : "http://\(device.ip):\(port)"
        let hik = "/ISAPI/Streaming/channels/\(channel * 100 + 1)/picture"
        let dahua = "/cgi-bin/snapshot.cgi?channel=\(channel)"
        let paths: [String]
        switch device.kind {
        case .hikvision: paths = [hik]
        case .dahua: paths = [dahua]
        default: paths = [hik, dahua]
        }

        var lastError = "Немає відповіді від камери."
        for path in paths {
            do {
                let data = try await Self.fetch(base + path, user: user, pass: pass)
                if let img = UIImage(data: data) {
                    image = img
                    errorText = nil
                    updatedAt = Date()
                    return
                }
                lastError = "Камера повернула не зображення."
            } catch let e as SnapError {
                lastError = e.message
                if e.isAuth { break }
            } catch {
                lastError = "Немає відповіді від камери."
            }
        }
        errorText = lastError
    }

    private static func fetch(_ urlString: String, user: String, pass: String) async throws -> Data {
        guard let url = URL(string: urlString) else { throw SnapError(message: "Некоректна адреса.", isAuth: false) }
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 6)
        do {
            let (data, resp) = try await URLSession.shared.data(for: req, delegate: AuthDelegate(user: user, pass: pass))
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if code == 401 { throw SnapError(message: "Невірний логін або пароль.", isAuth: true) }
            guard code == 200 else { throw SnapError(message: "Камера відповіла кодом \(code).", isAuth: false) }
            return data
        } catch let e as URLError where e.code == .userCancelledAuthentication {
            throw SnapError(message: "Невірний логін або пароль.", isAuth: true)
        }
    }
}

struct CameraToolsView: View {
    @EnvironmentObject private var scanner: NetworkScanner
    @StateObject private var snap = SnapshotLoader()
    @State private var selected: UInt32?
    @State private var user = "admin"
    @State private var password = ""
    @State private var channel = 1
    @State private var live = false
    @State private var liveTask: Task<Void, Never>?
    @State private var copiedKey: String?
    @State private var vlcMissing = false

    private var candidates: [NetworkDevice] {
        scanner.devices.filter { $0.kind.isCamera || $0.openPorts.contains(554) }
    }
    private var device: NetworkDevice? { candidates.first { $0.ipValue == selected } }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 14) {
                    if candidates.isEmpty {
                        Card {
                            SectionTitle(text: "Камери не знайдені", icon: "video.slash")
                            Text("Спочатку запустіть сканування на вкладці «Сканер».")
                                .font(.subheadline).foregroundColor(.white.opacity(0.7))
                        }
                    } else {
                        pickerCard
                        credentialsCard
                        snapshotCard
                        rtspCard
                    }
                    SiteFooter()
                }
                .padding(16)
            }
        }
        .navigationTitle("Камера")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if selected == nil { selected = candidates.first?.ipValue } }
        .onDisappear { live = false; liveTask?.cancel() }
        .onChange(of: live) { on in
            liveTask?.cancel()
            guard on else { return }
            liveTask = Task {
                while !Task.isCancelled {
                    if let d = device {
                        await snap.load(device: d, user: user, pass: password, channel: channel)
                    }
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }
        .alert("VLC не встановлено", isPresented: $vlcMissing) {
            Button("Відкрити App Store") {
                if let url = URL(string: "https://apps.apple.com/app/vlc-for-mobile/id650377962") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Скасувати", role: .cancel) {}
        } message: {
            Text("Для перегляду відеопотоку потрібен безкоштовний застосунок VLC for Mobile.")
        }
    }

    // MARK: - Блоки

    private var pickerCard: some View {
        Card {
            SectionTitle(text: "Камера", icon: "video.fill")
            Picker("Камера", selection: $selected) {
                ForEach(candidates) { d in
                    Text("\(d.ip) · \(d.model)").tag(Optional(d.ipValue))
                }
            }
            .pickerStyle(.menu)
            .tint(.cyan)
        }
    }

    private var credentialsCard: some View {
        Card {
            SectionTitle(text: "Вхід у камеру", icon: "key.fill")
            TextField("Логін", text: $user)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
            SecureField("Пароль", text: $password)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
            Stepper("Канал: \(channel)", value: $channel, in: 1...64)
            Text("Логін і пароль зберігаються лише в пам'яті, поки застосунок відкритий.")
                .font(.caption2).foregroundColor(.white.opacity(0.45))
        }
    }

    private var snapshotCard: some View {
        Card {
            SectionTitle(text: "Кадр з камери", icon: "photo")
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.4))
                if let img = snap.image {
                    Image(uiImage: img).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12))
                } else if snap.isLoading {
                    ProgressView().tint(.cyan)
                } else {
                    Image(systemName: "video.slash").font(.largeTitle).foregroundColor(.white.opacity(0.3))
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fit)

            if let error = snap.errorText { Text(error).font(.footnote).foregroundColor(.red) }
            if let t = snap.updatedAt {
                Text("Оновлено \(t.formatted(date: .omitted, time: .standard))")
                    .font(.caption2).foregroundColor(.white.opacity(0.45))
            }
            HStack {
                Button {
                    guard let d = device else { return }
                    Task { await snap.load(device: d, user: user, pass: password, channel: channel) }
                } label: {
                    Label("Отримати кадр", systemImage: "camera.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Capsule().fill(Color.cyan.opacity(0.25)))
                }
                .disabled(snap.isLoading)
                Spacer()
                Toggle("Наживо (2 с)", isOn: $live).toggleStyle(.switch).fixedSize().tint(.cyan)
            }
        }
    }

    private var rtspCard: some View {
        Card {
            SectionTitle(text: "RTSP-потік", icon: "play.rectangle.fill")
            rtspRow(title: "Основний потік", sub: false)
            Divider().overlay(Color.white.opacity(0.1))
            rtspRow(title: "Додатковий потік", sub: true)
            if device?.kind == .other || device?.kind == .camera {
                Text("Виробник невідомий — використано формат Hikvision. Якщо не відкривається, змініть шлях у VLC.")
                    .font(.caption2).foregroundColor(.white.opacity(0.45))
            }
        }
    }

    private func rtspRow(title: String, sub: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(rtsp(sub: sub, masked: true) ?? "—")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .textSelection(.enabled)
            HStack(spacing: 10) {
                Button {
                    guard let url = rtsp(sub: sub, masked: false) else { return }
                    UIPasteboard.general.string = url
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    copiedKey = title
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedKey = nil }
                } label: {
                    Label(copiedKey == title ? "Скопійовано" : "Копіювати",
                          systemImage: copiedKey == title ? "checkmark" : "doc.on.doc")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                Button {
                    guard let url = rtsp(sub: sub, masked: false) else { return }
                    openVLC(url)
                } label: {
                    Label("Відкрити у VLC", systemImage: "play.fill")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(Color.orange.opacity(0.3)))
                }
            }
        }
    }

    // MARK: - Логіка

    private func rtsp(sub: Bool, masked: Bool) -> String? {
        guard let d = device else { return nil }
        let u = user.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? user
        let p = masked ? "•••" : (password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? password)
        let auth = password.isEmpty ? u : "\(u):\(p)"
        let host = "\(auth)@\(d.ip):554"
        switch d.kind {
        case .dahua:
            return "rtsp://\(host)/cam/realmonitor?channel=\(channel)&subtype=\(sub ? 1 : 0)"
        default:
            return "rtsp://\(host)/Streaming/Channels/\(channel * 100 + (sub ? 2 : 1))"
        }
    }

    private func openVLC(_ rtspURL: String) {
        let encoded = rtspURL.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? rtspURL
        guard let url = URL(string: "vlc-x-callback://x-callback-url/stream?url=\(encoded)") else { return }
        UIApplication.shared.open(url, options: [:]) { ok in
            if !ok { vlcMissing = true }
        }
    }
}
