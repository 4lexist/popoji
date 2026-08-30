import AppKit
import SwiftUI

private struct EmojiStat: Identifiable {
    let emoji: Emoji
    let count: Int

    var id: String { emoji.id }
}

struct StatsView: View {
    @ObservedObject var usageStore: EmojiUsageStore

    private var stats: [EmojiStat] {
        Array(
            EmojiCatalog.all
                .compactMap { emoji in
                    guard let count = usageStore.counts[emoji.symbol], count > 0 else { return nil }
                    return EmojiStat(emoji: emoji, count: count)
                }
                .sorted { lhs, rhs in
                    if lhs.count != rhs.count {
                        return lhs.count > rhs.count
                    }
                    return lhs.emoji.name.localizedStandardCompare(rhs.emoji.name) == .orderedAscending
                }
                .prefix(100)
        )
    }

    var body: some View {
        Group {
            if stats.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No Emoji Usage Yet")
                        .font(.headline)
                    Text("Emoji you select in Popoji will appear here.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(stats) { stat in
                    HStack(spacing: 12) {
                        Text(stat.emoji.symbol)
                            .font(.system(size: 24))
                            .frame(width: 34)
                        Text(stat.emoji.name)
                            .lineLimit(1)
                        Spacer()
                        Text(stat.count, format: .number)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .frame(minWidth: 380, minHeight: 420)
    }
}

@MainActor
final class StatsWindowController: NSWindowController {
    init(usageStore: EmojiUsageStore) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Stats"
        // Popoji is a menu-bar-only app, so keep this window above regular app
        // windows and move it to whichever Space the user is currently viewing.
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: StatsView(usageStore: usageStore))
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        // Wait for the menu to dismiss before changing application and window
        // ordering; otherwise macOS can place the new window behind the app
        // that was active before the menu was opened.
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            NSApplication.shared.activate(ignoringOtherApps: true)
            self.showWindow(nil)
            window.orderFrontRegardless()
            window.makeKey()
        }
    }
}
