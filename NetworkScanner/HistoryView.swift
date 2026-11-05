import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var history: HistoryStore
    @State private var confirmClear = false

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 12) {
                    if history.records.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 34)).foregroundColor(.cyan.opacity(0.7))
                            Text("Історія порожня").font(.headline)
                            Text("Після кожного завершеного сканування результат зберігається тут.")
                                .font(.footnote).foregroundColor(.white.opacity(0.55))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                    } else {
                        ForEach(history.records) { record in
                            NavigationLink {
                                HistoryDetailView(record: record)
                            } label: {
                                row(record)
                            }
                            .buttonStyle(.plain)
                        }
                        Button(role: .destructive) {
                            confirmClear = true
                        } label: {
                            Label("Очистити історію", systemImage: "trash")
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                    }
                    SiteFooter()
                }
                .padding(16)
            }
        }
        .navigationTitle("Історія")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Видалити всю історію?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Видалити", role: .destructive) { history.clear() }
        }
    }

    private func row(_ record: ScanRecord) -> some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.headline)
                    Text(record.network)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(record.devices.count) пристроїв").font(.subheadline)
                    Text("\(record.cameraCount) камер").font(.caption).foregroundColor(.red)
                }
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.white.opacity(0.4))
            }
            if let diff = history.diff(for: record), !(diff.added.isEmpty && diff.removed.isEmpty) {
                HStack(spacing: 6) {
                    if !diff.added.isEmpty { Chip(text: "+\(diff.added.count) нових", color: .green) }
                    if !diff.removed.isEmpty { Chip(text: "−\(diff.removed.count) зникло", color: .red) }
                }
            }
        }
    }
}

struct HistoryDetailView: View {
    @EnvironmentObject private var history: HistoryStore
    let record: ScanRecord

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 12) {
                    Card {
                        InfoRow(label: "Дата", value: record.date.formatted(date: .complete, time: .standard), mono: false)
                        InfoRow(label: "Мережа", value: record.network)
                        InfoRow(label: "Пристроїв", value: "\(record.devices.count)")
                    }
                    if let diff = history.diff(for: record) {
                        if !diff.added.isEmpty {
                            Card {
                                SectionTitle(text: "Нові пристрої", icon: "plus.circle")
                                ForEach(diff.added) { InfoRow(label: $0.ip, value: $0.model, mono: false) }
                            }
                        }
                        if !diff.removed.isEmpty {
                            Card {
                                SectionTitle(text: "Зникли з мережі", icon: "minus.circle")
                                ForEach(diff.removed) { InfoRow(label: $0.ip, value: $0.model, mono: false) }
                            }
                        }
                    }
                    ForEach(record.devices) { DeviceCard(device: $0) }
                    SiteFooter()
                }
                .padding(16)
            }
        }
        .navigationTitle("Сканування")
        .navigationBarTitleDisplayMode(.inline)
    }
}
