import AppKit
import ApplicationServices

@MainActor
protocol KeyboardMonitorDelegate: AnyObject {
    func keyboardMonitor(_ monitor: KeyboardMonitor, didMatch query: String, near point: CGPoint)
    func keyboardMonitorMoveSelection(_ monitor: KeyboardMonitor, by offset: Int)
    func keyboardMonitorConfirmSelection(_ monitor: KeyboardMonitor)
    func keyboardMonitorCancelSelection(_ monitor: KeyboardMonitor)
}

final class KeyboardMonitor {
    private static let injectedEventMarker: Int64 = 0x504F504F4A49 // "POPOJI"

    weak var delegate: KeyboardMonitorDelegate?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var buffer = ""
    private(set) var isPickerVisible = false
    private var isInjectingText = false
    private var excludedBundleIdentifiers: Set<String> = []

    func setExcludedBundleIdentifiers(_ bundleIdentifiers: Set<String>) {
        excludedBundleIdentifiers = bundleIdentifiers
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        buffer = ""
    }

    func setPickerVisible(_ visible: Bool) {
        isPickerVisible = visible
        if !visible { buffer = "" }
    }

    func replaceTrigger(with emoji: String) {
        let triggerLength = buffer.count
        isPickerVisible = false
        buffer = ""
        isInjectingText = true

        let source = CGEventSource(stateID: .combinedSessionState)
        for _ in 0..<triggerLength {
            postKey(source: source, keyCode: 51, keyDown: true)
            postKey(source: source, keyCode: 51, keyDown: false)
        }

        let utf16 = Array(emoji.utf16)
        let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        utf16.withUnsafeBufferPointer { pointer in
            down?.keyboardSetUnicodeString(stringLength: pointer.count, unicodeString: pointer.baseAddress!)
        }
        down?.setIntegerValueField(.eventSourceUserData, value: Self.injectedEventMarker)
        down?.post(tap: .cghidEventTap)
        postKey(source: source, keyCode: 0, keyDown: false)

        DispatchQueue.main.async { [weak self] in self?.isInjectingText = false }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown,
              !isInjectingText,
              event.getIntegerValueField(.eventSourceUserData) != Self.injectedEventMarker
        else { return Unmanaged.passUnretained(event) }

        if let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           excludedBundleIdentifiers.contains(bundleIdentifier) {
            resetForExcludedApplication()
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        if isPickerVisible {
            switch keyCode {
            case 125: // down
                Task { @MainActor in self.delegate?.keyboardMonitorMoveSelection(self, by: 1) }
                return nil
            case 126: // up
                Task { @MainActor in self.delegate?.keyboardMonitorMoveSelection(self, by: -1) }
                return nil
            case 36, 76: // return / keypad enter
                Task { @MainActor in self.delegate?.keyboardMonitorConfirmSelection(self) }
                return nil
            case 53: // escape
                Task { @MainActor in self.delegate?.keyboardMonitorCancelSelection(self) }
                return nil
            case 51 where flags.contains(.maskCommand) || flags.contains(.maskAlternate): // command / option-delete
                Task { @MainActor in self.delegate?.keyboardMonitorCancelSelection(self) }
                return Unmanaged.passUnretained(event)
            case 51: // delete
                if buffer.count > 1 {
                    buffer.removeLast()
                    notifyQueryChanged()
                } else {
                    buffer = ""
                    isPickerVisible = false
                    Task { @MainActor in self.delegate?.keyboardMonitorCancelSelection(self) }
                }
                return Unmanaged.passUnretained(event)
            default:
                if !flags.contains(.maskCommand),
                   !flags.contains(.maskControl),
                   !flags.contains(.maskAlternate),
                   let characters = event.keyboardCharacters,
                   characters.count == 1,
                   Self.isQueryCharacter(characters) {
                    buffer.append(characters.lowercased())
                    notifyQueryChanged()
                }
                return Unmanaged.passUnretained(event)
            }
        }

        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
            buffer = ""
            return Unmanaged.passUnretained(event)
        }

        guard let characters = event.keyboardCharacters, characters.count == 1 else {
            if keyCode == 51 { buffer = String(buffer.dropLast()) } else { buffer = "" }
            return Unmanaged.passUnretained(event)
        }

        let character = characters.lowercased()
        if character == ":" {
            buffer = ":"
        } else if buffer.hasPrefix(":"), Self.isQueryCharacter(character) {
            buffer.append(character)
            if buffer.count >= 3 { notifyQueryChanged() }
        } else {
            buffer = ""
        }

        return Unmanaged.passUnretained(event)
    }

    private func resetForExcludedApplication() {
        buffer = ""
        guard isPickerVisible else { return }
        isPickerVisible = false
        Task { @MainActor in self.delegate?.keyboardMonitorCancelSelection(self) }
    }

    private func notifyQueryChanged() {
        let query = String(buffer.dropFirst())
        let point = Self.focusedCaretPoint() ?? NSEvent.mouseLocation
        Task { @MainActor in self.delegate?.keyboardMonitor(self, didMatch: query, near: point) }
    }

    private static func isQueryCharacter(_ character: String) -> Bool {
        character.range(of: "^[a-zA-Z0-9+-]$", options: .regularExpression) != nil
    }

    private func postKey(source: CGEventSource?, keyCode: CGKeyCode, keyDown: Bool) {
        let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)
        event?.setIntegerValueField(.eventSourceUserData, value: Self.injectedEventMarker)
        event?.post(tap: .cghidEventTap)
    }

    private static func focusedCaretPoint() -> CGPoint? {
        let system = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedValue else { return nil }
        let focused = focusedValue as! AXUIElement

        // Web-based editors commonly expose text-marker ranges instead of the
        // standard CFRange-based attributes used by native text controls.
        if let rect = textMarkerBounds(in: focused) {
            guard let primaryScreen = NSScreen.screens.first else { return nil }
            return CGPoint(x: rect.minX, y: primaryScreen.frame.maxY - rect.minY)
        }

        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue else { return nil }

        let selectedRangeValue = rangeValue as! AXValue
        var selectedRange = CFRange()
        guard AXValueGetType(selectedRangeValue) == .cfRange,
              AXValueGetValue(selectedRangeValue, .cfRange, &selectedRange)
        else { return nil }

        var caretX: CGFloat
        var caretY: CGFloat
        if let rect = bounds(for: selectedRangeValue, in: focused) {
            caretX = rect.minX
            caretY = rect.minY
        } else if selectedRange.location > 0 {
            // Chromium-based editors can expose a selected range but no bounds for
            // its zero-length insertion point. The trailing edge of the preceding
            // character is the same caret position.
            var precedingRange = CFRange(location: selectedRange.location - 1, length: 1)
            guard let precedingRangeValue = AXValueCreate(.cfRange, &precedingRange),
                  let rect = bounds(for: precedingRangeValue, in: focused)
            else { return nil }
            caretX = rect.maxX
            caretY = rect.minY
        } else {
            // At the start of the text there is no preceding character, so use the
            // leading edge of the first character instead.
            var firstRange = CFRange(location: 0, length: 1)
            guard let firstRangeValue = AXValueCreate(.cfRange, &firstRange),
                  let rect = bounds(for: firstRangeValue, in: focused)
            else { return nil }
            caretX = rect.minX
            caretY = rect.minY
        }

        // Accessibility coordinates start at the top-left; AppKit starts at the bottom-left.
        // Return the caret's upper-left corner so the picker can sit directly above it.
        guard let primaryScreen = NSScreen.screens.first else { return nil }
        return CGPoint(x: caretX, y: primaryScreen.frame.maxY - caretY)
    }

    private static func textMarkerBounds(in element: AXUIElement) -> CGRect? {
        var markerRange: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            "AXSelectedTextMarkerRange" as CFString,
            &markerRange
        ) == .success,
              let markerRange
        else { return nil }

        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            "AXBoundsForTextMarkerRange" as CFString,
            markerRange,
            &boundsValue
        ) == .success,
              let boundsValue
        else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect),
              rect.height > 0,
              rect.minX.isFinite,
              rect.minY.isFinite
        else { return nil }
        return rect
    }

    private static func bounds(for range: AXValue, in element: AXUIElement) -> CGRect? {
        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            range,
            &boundsValue
        ) == .success,
              let boundsValue
        else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect),
              rect.height > 0,
              rect.minX.isFinite,
              rect.minY.isFinite
        else { return nil }
        return rect
    }
}

private extension CGEvent {
    var keyboardCharacters: String? {
        var length = 0
        keyboardGetUnicodeString(maxStringLength: 0, actualStringLength: &length, unicodeString: nil)
        guard length > 0 else { return nil }
        var buffer = [UniChar](repeating: 0, count: length)
        keyboardGetUnicodeString(maxStringLength: length, actualStringLength: &length, unicodeString: &buffer)
        return String(utf16CodeUnits: buffer, count: length)
    }
}
