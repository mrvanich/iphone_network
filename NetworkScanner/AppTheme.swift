import SwiftUI

struct AppBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.04, green: 0.07, blue: 0.16),
                                Color(red: 0.06, green: 0.02, blue: 0.20)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}

struct Card<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

struct InfoRow: View {
    let label: String
    let value: String?
    var mono = true

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.subheadline).foregroundColor(.white.opacity(0.6))
            Spacer(minLength: 12)
            Text(value ?? "—")
                .font(mono ? .system(.subheadline, design: .monospaced) : .subheadline)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}

struct SectionTitle: View {
    let text: String
    let icon: String
    var body: some View {
        Label(text, systemImage: icon)
            .font(.headline)
            .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
    }
}

struct SiteFooter: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("Створено mrVanich")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.45))
            if let url = URL(string: "https://vanich.cv.ua") {
                Link(destination: url) {
                    Label("vanich.cv.ua", systemImage: "link")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }
}

struct Chip: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.22)))
            .foregroundColor(color)
    }
}
