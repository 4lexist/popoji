import SwiftUI

struct PickerView: View {
    private static let maximumVisibleRows = 8
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
        .padding(.vertical, 6)
        .frame(width: 320)
        .background(.ultraThickMaterial)
    }

    private var listHeight: CGFloat {
        let visibleRows = min(emojis.count, Self.maximumVisibleRows)
        return CGFloat(visibleRows) * Self.rowHeight
            + CGFloat(max(visibleRows - 1, 0)) * Self.rowSpacing
    }

    private func scrollToSelection(using proxy: ScrollViewProxy) {
        guard emojis.indices.contains(selectedIndex) else { return }
        proxy.scrollTo(selectedIndex)
    }
}
