import AppKit
import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusMenuController: StatusMenuController!
    private let eventTapManager = EventTapManager()
    private var axPollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let savedDelay = (UserDefaults.standard.object(forKey: DefaultsKeys.delayMs) as? Int) ?? 200
        let savedActivation = (UserDefaults.standard.object(forKey: DefaultsKeys.activationDelayMs) as? Int) ?? 20
        let savedTrigger = UserDefaults.standard.string(forKey: DefaultsKeys.trigger) ?? "keyUp"
        let savedBlockDown = (UserDefaults.standard.object(forKey: DefaultsKeys.blockMouseDown) as? Bool) ?? true
        let savedBlockUp = (UserDefaults.standard.object(forKey: DefaultsKeys.blockMouseUp) as? Bool) ?? false
        let runAtLoginEnabled = isRunAtLoginEnabled()

        statusMenuController = StatusMenuController(
            initialDelayMs: savedDelay,
            initialActivationDelayMs: savedActivation,
            initialTrigger: savedTrigger,
            initialBlockMouseDown: savedBlockDown,
            initialBlockMouseUp: savedBlockUp,
            initialRunAtLoginEnabled: runAtLoginEnabled,
            onDelayChanged: { [weak self] newDelay in
                self?.eventTapManager.delayMs = newDelay
            },
            onActivationDelayChanged: { [weak self] newActivation in
                self?.eventTapManager.activationDelayMs = newActivation
            },
            onTriggerChanged: { [weak self] newTrigger in
                self?.eventTapManager.trigger = (newTrigger == "keyDown") ? .keyDown : .keyUp
            },
            onBlockingChanged: { [weak self] blockDown, blockUp in
                self?.eventTapManager.blockMouseDown = blockDown
                self?.eventTapManager.blockMouseUp = blockUp
            },
            onRunAtLoginChanged: { [weak self] enabled in
                self?.setRunAtLogin(enabled) ?? false
            }
        )

        statusMenuController.onEnableChanged = { [weak self] enabled in
            self?.eventTapManager.isEnabled = enabled
        }

        statusMenuController.onRequestAXPrompt = { [weak self] in
            guard let self = self else { return }
            self.eventTapManager.promptForAccessibilityIfNeeded()
            self.openAccessibilityPreferences()
            if self.eventTapManager.isAccessibilityTrusted {
                self.eventTapManager.start()
            } else {
                self.beginAXAuthorizationPolling()
            }
            self.statusMenuController.updateAXAuthorized(self.eventTapManager.isAccessibilityTrusted)
        }

        eventTapManager.onStatusChange = { [weak self] status in
            self?.statusMenuController.updateStatus(status: status)
        }

        // Configure from persisted defaults
        eventTapManager.delayMs = savedDelay
        eventTapManager.activationDelayMs = savedActivation
        eventTapManager.trigger = (savedTrigger == "keyDown") ? .keyDown : .keyUp
        eventTapManager.blockMouseDown = savedBlockDown
        eventTapManager.blockMouseUp = savedBlockUp
        eventTapManager.isEnabled = savedDelay > 0

        // Start monitoring; if AX missing, UI will reflect it
        eventTapManager.start()
        let trusted = eventTapManager.isAccessibilityTrusted
        statusMenuController.updateAXAuthorized(trusted)
        if !trusted {
            beginAXAuthorizationPolling()
        }
    }

    private func beginAXAuthorizationPolling() {
        axPollTimer?.invalidate()
        axPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            let trusted = self.eventTapManager.isAccessibilityTrusted
            self.statusMenuController.updateAXAuthorized(trusted)
            if trusted {
                timer.invalidate()
                self.axPollTimer = nil
                self.eventTapManager.start()
            }
        }
    }

    private func openAccessibilityPreferences() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func applicationWillTerminate(_ notification: Notification) {
        axPollTimer?.invalidate()
        axPollTimer = nil
    }

    private func isRunAtLoginEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    private func setRunAtLogin(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return isRunAtLoginEnabled()
        } catch {
            NSLog("Failed to update Run at Login: \(error.localizedDescription)")
            NSSound.beep()
            return isRunAtLoginEnabled()
        }
    }
}

enum DefaultsKeys {
    static let delayMs = "delayMs"
    static let activationDelayMs = "activationDelayMs"
    static let trigger = "trigger"
    static let blockMouseDown = "blockMouseDown"
    static let blockMouseUp = "blockMouseUp"
}
