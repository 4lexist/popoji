import SwiftUI
import ApplicationServices

@main
struct PopojiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Popoji", systemImage: "face.smiling") {
            MenuContent(appDelegate: appDelegate)
        }
    }
}

private struct MenuContent: View {
    @ObservedObject var appDelegate: AppDelegate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appDelegate.statusText)
            Text("Type : and two letters, numbers, +, or - in any app")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Button("Stats") {
                appDelegate.showStats()
            }
            Button("Check Accessibility Permission") {
                appDelegate.requestPermissionAndStart()
            }
            Button("Quit Popoji") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding(8)
        .onAppear {
            appDelegate.refreshPermissionAndStart()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, KeyboardMonitorDelegate {
    @Published var statusText = "Starting…"

    private let monitor = KeyboardMonitor()
    private let usageStore = EmojiUsageStore()
    private lazy var picker = PickerController(usageStore: usageStore)
    private lazy var stats = StatsWindowController(usageStore: usageStore)
    private var didRequestInitialStart = false
    private var permissionPollTimer: Timer?

    override init() {
        super.init()
        configureComponents()

        // Keep startup independent of the menu scene's launch-callback timing.
        // The guard makes this safe when applicationDidFinishLaunching also runs.
        DispatchQueue.main.async { [weak self] in
            self?.requestInitialStartIfNeeded()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestInitialStartIfNeeded()
    }

    private func configureComponents() {
        monitor.delegate = self
        picker.onSelect = { [weak self] emoji in
            self?.monitor.replaceTrigger(with: emoji.symbol)
            self?.monitor.setPickerVisible(false)
        }
    }

    private func requestInitialStartIfNeeded() {
        guard !didRequestInitialStart else { return }
        didRequestInitialStart = true
        requestPermissionAndStart()
    }

    func requestPermissionAndStart() {
        updatePermissionAndStart(promptIfNeeded: true)
    }

    func refreshPermissionAndStart() {
        updatePermissionAndStart(promptIfNeeded: false)
    }

    func showStats() {
        stats.show()
    }

    private func updatePermissionAndStart(promptIfNeeded: Bool) {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: promptIfNeeded
        ] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            monitor.stop()
            statusText = "Accessibility permission required"
            startPermissionPolling()
            return
        }
        stopPermissionPolling()
        statusText = monitor.start() ? "Listening" : "Could not start keyboard listener"
    }

    private func startPermissionPolling() {
        guard permissionPollTimer == nil else { return }

        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard AXIsProcessTrusted() else { return }

            Task { @MainActor [weak self] in
                self?.updatePermissionAndStart(promptIfNeeded: false)
            }
        }
    }

    private func stopPermissionPolling() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = nil
    }

    func keyboardMonitor(_ monitor: KeyboardMonitor, didMatch query: String, near point: CGPoint) {
        picker.show(query: query, near: point)
        monitor.setPickerVisible(true)
    }

    func keyboardMonitorMoveSelection(_ monitor: KeyboardMonitor, by offset: Int) {
        picker.moveSelection(by: offset)
    }

    func keyboardMonitorConfirmSelection(_ monitor: KeyboardMonitor) {
        picker.confirmSelection()
        monitor.setPickerVisible(false)
    }

    func keyboardMonitorCancelSelection(_ monitor: KeyboardMonitor) {
        picker.close()
        monitor.setPickerVisible(false)
    }
}
