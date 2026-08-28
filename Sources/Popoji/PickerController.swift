import AppKit
import SwiftUI

@MainActor
final class PickerController {
    private let panel: PickerPanel
    private var query = ""
    private var emojis: [Emoji] = []
    private var selectedIndex = 0
    var onSelect: ((Emoji) -> Void)?

    init() {
        panel = PickerPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 94),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
    }

    func show(query: String, near point: CGPoint) {
        self.query = query
        emojis = EmojiCatalog.search(query)
        selectedIndex = 0
        refreshContent()

        let size = panel.contentView?.fittingSize ?? NSSize(width: 520, height: 94)
        var origin = CGPoint(x: point.x, y: point.y - size.height - 8)
        let screen = NSScreen.screens.first { $0.visibleFrame.contains(point) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
            if origin.y < visible.minY + 8 { origin.y = point.y + 20 }
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
    }

    func moveSelection(by offset: Int) {
        guard !emojis.isEmpty else { return }
        selectedIndex = (selectedIndex + offset + emojis.count) % emojis.count
        refreshContent()
    }

    func confirmSelection() {
        guard emojis.indices.contains(selectedIndex) else {
            close()
            return
        }
        choose(emojis[selectedIndex])
    }

    func close() {
        panel.orderOut(nil)
    }

    private func choose(_ emoji: Emoji) {
        close()
        onSelect?(emoji)
    }

    private func refreshContent() {
        panel.contentView = NSHostingView(rootView: PickerView(
            query: query,
            emojis: emojis,
            selectedIndex: selectedIndex,
            onSelect: { [weak self] emoji in self?.choose(emoji) }
        ))
    }
}

final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
