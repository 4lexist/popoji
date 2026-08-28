import SwiftUI

struct PickerView: View {
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
                VStack(spacing: 2) {
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
                            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                            .background(index == selectedIndex ? Color.accentColor.opacity(0.22) : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .frame(width: 320)
        .background(.ultraThickMaterial)
    }
}
