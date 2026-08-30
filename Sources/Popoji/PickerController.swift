import AppKit
import SwiftUI

@MainActor
final class PickerController {
    private enum Placement {
        case aboveCaret
        case belowCaret
    }

    private let panel: PickerPanel
    private let usageStore: EmojiUsageStore
    private let skinToneStore: SkinToneStore
    private var query = ""
    private var emojis: [Emoji] = []
    private var selectedIndex = 0
    private var placement = Placement.aboveCaret
    var onSelect: ((Emoji) -> Void)?

    init(usageStore: EmojiUsageStore, skinToneStore: SkinToneStore) {
        self.usageStore = usageStore
        self.skinToneStore = skinToneStore
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
        emojis = EmojiCatalog.search(query, usageCounts: usageStore.counts)
        selectedIndex = 0
        refreshContent()

        // Keep the picker anchored where it first opened. Query changes arrive
        // after every typed character, and the caret moves with them; positioning
        // the panel again here would make it follow the caret across the line.
        guard !panel.isVisible else { return }

        let size = panel.contentView?.fittingSize ?? NSSize(width: 520, height: 94)
        let caretGap: CGFloat = 8
        // NSWindow origins are bottom-left, so this keeps the picker's bottom-left
        // corner directly above the caret.
        var origin = CGPoint(x: point.x, y: point.y + caretGap)
        placement = .aboveCaret
        let screen = NSScreen.screens.first { $0.visibleFrame.contains(point) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            if origin.y + size.height > visible.maxY - 8 {
                origin.y = max(visible.minY + 8, point.y - size.height - caretGap)
                placement = .belowCaret
            }
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
        usageStore.recordUse(of: emoji)
        close()
        onSelect?(emoji)
    }

    private func refreshContent() {
        let previousFrame = panel.frame
        let wasVisible = panel.isVisible
        let hostingView = NSHostingView(rootView: PickerView(
            emojis: emojis,
            selectedIndex: selectedIndex,
            skinToneStore: skinToneStore,
            onSelect: { [weak self] emoji in self?.choose(emoji) }
        ))
        panel.contentView = hostingView

        guard wasVisible else { return }

        let size = hostingView.fittingSize
        let originY: CGFloat
        switch placement {
        case .aboveCaret:
            // Keep the bottom edge beside the caret, so fewer results remove
            // rows from the top of the picker instead of opening up a gap.
            originY = previousFrame.minY
        case .belowCaret:
            // Below the caret, the top edge is the caret-facing edge.
            originY = previousFrame.maxY - size.height
        }

        panel.setFrame(
            NSRect(x: previousFrame.minX, y: originY, width: size.width, height: size.height),
            display: true
        )
    }
}

final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
