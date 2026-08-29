import SwiftUI

struct PickerView: View {
    private static let fullyVisibleRows = 7
    private static let partialRowFraction: CGFloat = 0.5
    private static let rowHeight: CGFloat = 30
    private static let rowSpacing: CGFloat = 2

    let emojis: [Emoji]
    let selectedIndex: Int
    let onSelect: (Emoji) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if emojis.isEmpty {
                Text("No matching emoji")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 46)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(spacing: Self.rowSpacing) {
                            ForEach(Array(emojis.enumerated()), id: \.element.id) { index, emoji in
                                Button {
                                    onSelect(emoji)
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(emoji.symbol)
                                            .font(.system(size: 24))
                                            .frame(width: 32)
                                        Text(emoji.name)
                                            .font(.callout)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .frame(maxWidth: .infinity, minHeight: Self.rowHeight, alignment: .leading)
                                    .background(index == selectedIndex ? Color.accentColor.opacity(0.22) : Color.clear)
                                }
                                .buttonStyle(.plain)
                                .id(index)
                            }
                        }
                    }
                    .frame(height: listHeight)
                    .onAppear { scrollToSelection(using: proxy) }
                    .onChange(of: selectedIndex) { _ in scrollToSelection(using: proxy) }
                }
            }
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
    }

    private var listHeight: CGFloat {
        let fullRows = min(emojis.count, Self.fullyVisibleRows)
        let hasPartialRow = emojis.count > Self.fullyVisibleRows
        let visibleSpacings = min(max(emojis.count - 1, 0), Self.fullyVisibleRows)

        return CGFloat(fullRows) * Self.rowHeight
            + (hasPartialRow ? Self.rowHeight * Self.partialRowFraction : 0)
            + CGFloat(visibleSpacings) * Self.rowSpacing
    }

    private func scrollToSelection(using proxy: ScrollViewProxy) {
        guard emojis.indices.contains(selectedIndex) else { return }
        proxy.scrollTo(selectedIndex)
    }
}
