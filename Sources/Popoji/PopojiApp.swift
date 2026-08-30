import SwiftUI
import ApplicationServices

@main
struct PopojiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Popoji", systemImage: "face.smiling") {
            MenuContent(
                appDelegate: appDelegate,
                exclusionStore: appDelegate.exclusionStore,
                skinToneStore: appDelegate.skinToneStore
            )
        }
    }
}

private struct MenuContent: View {
    @ObservedObject var appDelegate: AppDelegate
    @ObservedObject var exclusionStore: AppExclusionStore
    @ObservedObject var skinToneStore: SkinToneStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appDelegate.statusText)
            Text("Type : + the emoji name")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Button(appDelegate.exclusionActionTitle) {
                appDelegate.toggleExclusionForCurrentApplication()
            }
            .disabled(appDelegate.currentApplication == nil)
            Menu("Disabled Apps") {
                if exclusionStore.applications.isEmpty {
                    Text("None")
                } else {
                    ForEach(exclusionStore.applications) { application in
                        Button("Enable in \(application.displayName)") {
                            appDelegate.enablePopoji(in: application)
                        }
                    }
                }
            }
            Menu("Skin Tone") {
                ForEach(SkinTone.allCases) { skinTone in
                    Button {
                        skinToneStore.selected = skinTone
                    } label: {
                        if skinToneStore.selected == skinTone {
                            Label("\(skinTone.preview)  \(skinTone.name)", systemImage: "checkmark")
                        } else {
                            Text("\(skinTone.preview)  \(skinTone.name)")
                        }
                    }
                }
            }
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
    @Published private(set) var currentApplication: ExcludedApplication?

    private let monitor = KeyboardMonitor()
    private let usageStore = EmojiUsageStore()
    let exclusionStore = AppExclusionStore()
    let skinToneStore = SkinToneStore()
    private lazy var picker = PickerController(
        usageStore: usageStore,
        skinToneStore: skinToneStore
    )
    private lazy var stats = StatsWindowController(
        usageStore: usageStore,
        skinToneStore: skinToneStore
    )
    private var didRequestInitialStart = false
    private var permissionPollTimer: Timer?
    private var activationObserver: NSObjectProtocol?

    override init() {
        super.init()
        configureComponents()
        observeApplicationChanges()

        // Keep startup independent of the menu scene's launch-callback timing.
        // The guard makes this safe when applicationDidFinishLaunching also runs.
        DispatchQueue.main.async { [weak self] in
            self?.requestInitialStartIfNeeded()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestInitialStartIfNeeded()
    }

    deinit {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }

    private func configureComponents() {
        monitor.delegate = self
        monitor.setExcludedBundleIdentifiers(exclusionStore.bundleIdentifiers)
        picker.onSelect = { [weak self] emoji in
            guard let self else { return }
            let symbol = self.skinToneStore.selected.applying(to: emoji.symbol)
            self.monitor.replaceTrigger(with: symbol)
            self.monitor.setPickerVisible(false)
        }
    }

    private func observeApplicationChanges() {
        updateCurrentApplication(NSWorkspace.shared.frontmostApplication)
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor [weak self] in
                self?.updateCurrentApplication(application)
            }
        }
    }

    private func updateCurrentApplication(_ application: NSRunningApplication?) {
        guard let application,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let bundleIdentifier = application.bundleIdentifier
        else { return }

        currentApplication = ExcludedApplication(
            bundleIdentifier: bundleIdentifier,
            displayName: application.localizedName ?? bundleIdentifier
        )

        if exclusionStore.contains(bundleIdentifier: bundleIdentifier) {
            picker.close()
            monitor.setPickerVisible(false)
        }
    }

    var exclusionActionTitle: String {
        guard let currentApplication else { return "Disable in Current App" }
        let action = exclusionStore.contains(bundleIdentifier: currentApplication.bundleIdentifier)
            ? "Enable"
            : "Disable"
        return "\(action) in \(currentApplication.displayName)"
    }

    func toggleExclusionForCurrentApplication() {
        guard let currentApplication else { return }
        if exclusionStore.contains(bundleIdentifier: currentApplication.bundleIdentifier) {
            exclusionStore.include(bundleIdentifier: currentApplication.bundleIdentifier)
        } else {
            exclusionStore.exclude(currentApplication)
            picker.close()
            monitor.setPickerVisible(false)
        }
        monitor.setExcludedBundleIdentifiers(exclusionStore.bundleIdentifiers)
    }

    func enablePopoji(in application: ExcludedApplication) {
        exclusionStore.include(bundleIdentifier: application.bundleIdentifier)
        monitor.setExcludedBundleIdentifiers(exclusionStore.bundleIdentifiers)
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
