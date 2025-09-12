import AppKit
import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusMenuController: StatusMenuController!
    private let eventTapManager = EventTapManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let savedDelay = (UserDefaults.standard.object(forKey: DefaultsKeys.delayMs) as? Int) ?? 200
        let savedActivation = (UserDefaults.standard.object(forKey: DefaultsKeys.activationDelayMs) as? Int) ?? 20
        let savedTrigger = UserDefaults.standard.string(forKey: DefaultsKeys.trigger) ?? "keyUp"
        let savedBlockDown = (UserDefaults.standard.object(forKey: DefaultsKeys.blockMouseDown) as? Bool) ?? true
        let savedBlockUp = (UserDefaults.standard.object(forKey: DefaultsKeys.blockMouseUp) as? Bool) ?? false

        statusMenuController = StatusMenuController(
            initialDelayMs: savedDelay,
            initialActivationDelayMs: savedActivation,
            initialTrigger: savedTrigger,
            initialBlockMouseDown: savedBlockDown,
            initialBlockMouseUp: savedBlockUp,
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
            }
        )

        statusMenuController.onEnableChanged = { [weak self] enabled in
            self?.eventTapManager.isEnabled = enabled
        }

        statusMenuController.onRequestAXPrompt = { [weak self] in
            self?.eventTapManager.promptForAccessibilityIfNeeded()
            self?.statusMenuController.updateAXAuthorized(self?.eventTapManager.isAccessibilityTrusted ?? false)
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
        statusMenuController.updateAXAuthorized(eventTapManager.isAccessibilityTrusted)
    }

    func applicationWillTerminate(_ notification: Notification) { }
}

enum DefaultsKeys {
    static let delayMs = "delayMs"
    static let activationDelayMs = "activationDelayMs"
    static let trigger = "trigger"
    static let blockMouseDown = "blockMouseDown"
    static let blockMouseUp = "blockMouseUp"
}
