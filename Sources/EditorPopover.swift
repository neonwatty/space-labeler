import SwiftUI

struct EditorPopover: View {
    @ObservedObject var monitor: SpaceMonitor
    @ObservedObject var store: SpaceStore

    @State private var nameBuffer: String = ""
    @State private var bufferedID: UInt64 = 0

    private let palette = ["#FF6B6B", "#4ECDC4", "#FFE66D", "#95E1D3", "#C7B8EA", "#FFA07A"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Current Space")
            currentCard

            sectionLabel("All Spaces")
            spaceList

            Divider()

            HStack {
                Button("Preferences…") {}
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(13)
        .frame(width: 290)
        .onAppear { syncBuffer() }
        .onChange(of: monitor.currentSpaceID) { _ in syncBuffer() }
    }

    private func syncBuffer() {
        bufferedID = monitor.currentSpaceID
        nameBuffer = store.label(for: monitor.currentSpaceID).name
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }

    private var currentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Space name", text: $nameBuffer)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .onChange(of: nameBuffer) { newValue in
                    var l = store.label(for: bufferedID)
                    l.name = newValue
                    store.update(bufferedID, l)
                }

            HStack(spacing: 7) {
                ForEach(palette, id: \.self) { hex in
                    swatch(hex: hex)
                }
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.055))
        )
    }

    private func swatch(hex: String) -> some View {
        let current = store.label(for: bufferedID)
        let isSelected = current.colorHex == hex
        return Circle()
            .fill(Color(hex: hex) ?? .white)
            .frame(width: 24, height: 24)
            .overlay(
                Circle().stroke(Color.white, lineWidth: isSelected ? 2 : 0)
            )
            .contentShape(Circle())
            .onTapGesture {
                var l = store.label(for: bufferedID)
                l.colorHex = hex
                store.update(bufferedID, l)
            }
    }

    private var spaceList: some View {
        VStack(spacing: 1) {
            ForEach(store.labels.keys.sorted(), id: \.self) { id in
                spaceRow(id: id)
            }
        }
    }

    private func spaceRow(id: UInt64) -> some View {
        let label = store.labels[id] ?? SpaceLabel(name: "?", colorHex: "#888888")
        let isCurrent = id == monitor.currentSpaceID
        return HStack(spacing: 9) {
            Circle()
                .fill(Color(hex: label.colorHex) ?? .gray)
                .frame(width: 10, height: 10)
            Text(label.name)
                .font(.system(size: 13))
            Spacer()
            if isCurrent {
                Text("current")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isCurrent ? Color.accentColor.opacity(0.16) : Color.clear)
        )
    }
}

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
