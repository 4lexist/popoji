import SwiftUI

struct PickerView: View {
    let query: String
    let emojis: [Emoji]
    let selectedIndex: Int
    let onSelect: (Emoji) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(":" + query)
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("↑↓ select  ↩ insert  esc close")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if emojis.isEmpty {
                Text("No matching emoji")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 46)
            } else {
                HStack(spacing: 6) {
                    ForEach(Array(emojis.enumerated()), id: \.element.id) { index, emoji in
                        Button {
                            onSelect(emoji)
                        } label: {
                            VStack(spacing: 3) {
                                Text(emoji.symbol).font(.system(size: 28))
                                Text(emoji.name)
                                    .font(.system(size: 9))
                                    .lineLimit(1)
                            }
                            .frame(width: 56, height: 52)
                            .background(index == selectedIndex ? Color.accentColor.opacity(0.22) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 520)
        .background(.ultraThickMaterial)
    }
}
