import SwiftUI

struct AdditionalView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 14) {
                        Text("Додатково")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [.cyan, .blue, .purple],
                                                            startPoint: .leading, endPoint: .trailing))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        NavigationLink { CameraToolsView() } label: {
                            menuCard(icon: "video.fill", color: .red, title: "Камера: кадр і RTSP",
                                     text: "Перегляд кадру з камери, RTSP-посилання, відкриття у VLC")
                        }
                        NavigationLink { OnvifView() } label: {
                            menuCard(icon: "checkmark.seal.fill", color: .green, title: "Перевірка ONVIF",
                                     text: "Виробник, модель, прошивка та серійний номер камер")
                        }
                        NavigationLink { HistoryView() } label: {
                            menuCard(icon: "clock.arrow.circlepath", color: .purple, title: "Історія сканувань",
                                     text: "Збережені результати та зміни в мережі між скануваннями")
                        }
                        SiteFooter()
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func menuCard(icon: String, color: Color, title: String, text: String) -> some View {
        Card {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(color.opacity(0.18)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(text).font(.footnote).foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.white.opacity(0.4))
            }
        }
    }
}
