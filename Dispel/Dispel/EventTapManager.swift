import Cocoa
import CoreGraphics
import ApplicationServices

final class EventTapManager {
    enum Status: String {
        case active = "Active"
        case off = "Off"
        case noPermission = "No Permission"
        case error = "Error"
    }

    // Public controls
    enum Trigger: String { case keyDown, keyUp }
    var trigger: Trigger = .keyUp { didSet { /* applies on next key event */ } }
    var delayMs: Int = 200 { didSet { normalizeDelaySettings(); handleConfigurationChange() } }
    var activationDelayMs: Int = 20 { didSet { normalizeDelaySettings(); handleConfigurationChange() } }
    var blockMouseDown: Bool = true
    var blockMouseUp: Bool = false
    var isEnabled: Bool = true { didSet { handleEnablementChange() } }

    // Callbacks
    var onStatusChange: ((Status) -> Void)?

    // Internal
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var startTimer: DispatchSourceTimer?
    private var endTimer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.dispel.timer")
    private let stateLock = NSLock()
    private var suppressionStart: DispatchTime?
    private var suppressionEnd: DispatchTime?

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    func promptForAccessibilityIfNeeded() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: NSDictionary = [promptKey: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func start() {
        guard isAccessibilityTrusted else {
            emitStatus(.noPermission)
            return
        }

        if eventTap != nil { stop() }

        let mask: CGEventMask =
            (CGEventMask(1) << CGEventType.keyDown.rawValue) |
            (CGEventMask(1) << CGEventType.keyUp.rawValue) |
            (CGEventMask(1) << CGEventType.leftMouseDown.rawValue) |
            (CGEventMask(1) << CGEventType.leftMouseUp.rawValue) |
            (CGEventMask(1) << CGEventType.rightMouseDown.rawValue) |
            (CGEventMask(1) << CGEventType.rightMouseUp.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            let unmanaged = Unmanaged<EventTapManager>.fromOpaque(refcon!)
            let manager = unmanaged.takeUnretainedValue()
            return manager.handleEvent(proxy: proxy, type: type, event: event)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: selfPtr
        ) else {
            emitStatus(.error)
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let src = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            emitStatus(isEnabled && delayMs > 0 ? .active : .off)
        }

        ensureTimersConfigured()
    }

    func stop() {
        stateLock.lock()
        let startTimer = self.startTimer
        let endTimer = self.endTimer
        self.startTimer = nil
        self.endTimer = nil
        suppressionStart = nil
        suppressionEnd = nil
        stateLock.unlock()

        startTimer?.cancel()
        endTimer?.cancel()
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
        }
        runLoopSource = nil
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        eventTap = nil
        emitStatus(.off)
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Recover from timeout/disabled
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        // Update timers on chosen trigger
        let isTrigger: Bool = {
            switch trigger {
            case .keyDown: return type == .keyDown
            case .keyUp:   return type == .keyUp
            }
        }()
        if isTrigger {
            if isEnabled && delayMs > 0 { armSuppressionTimers() }
            return Unmanaged.passUnretained(event)
        }

        // During suppression, drop configured mouse phases
        if isSuppressionActive {
            switch type {
            case .leftMouseDown, .rightMouseDown:
                if blockMouseDown { return nil }
            case .leftMouseUp, .rightMouseUp:
                if blockMouseUp { return nil }
            default: break
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private var isSuppressionActive: Bool {
        stateLock.lock()
        let start = suppressionStart
        let end = suppressionEnd
        stateLock.unlock()
        guard let start, let end else { return false }
        let now = DispatchTime.now()
        return now >= start && now < end
    }

    private func ensureTimersConfigured() {
        stateLock.lock()
        if startTimer != nil && endTimer != nil {
            stateLock.unlock()
            return
        }

        let startTimer = DispatchSource.makeTimerSource(queue: timerQueue)
        let endTimer = DispatchSource.makeTimerSource(queue: timerQueue)
        self.startTimer = startTimer
        self.endTimer = endTimer
        stateLock.unlock()

        startTimer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.stateLock.lock()
            let end = self.suppressionEnd ?? (DispatchTime.now() + .milliseconds(self.delayMs))
            self.suppressionStart = DispatchTime.now()
            self.suppressionEnd = end
            self.stateLock.unlock()
        }
        endTimer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.stateLock.lock()
            self.suppressionStart = nil
            self.suppressionEnd = nil
            self.stateLock.unlock()
            self.emitStatus((self.isEnabled && self.delayMs > 0) ? .active : .off)
        }
        startTimer.resume()
        endTimer.resume()
    }

    private func armSuppressionTimers() {
        let delay = max(0, delayMs)
        let activation = max(0, activationDelayMs)
        if delay == 0 {
            clearSuppressionWindow()
            return
        }
        ensureTimersConfigured()
        let start = DispatchTime.now() + .milliseconds(activation)
        let end = start + .milliseconds(delay)
        stateLock.lock()
        suppressionStart = start
        suppressionEnd = end
        let startTimer = self.startTimer
        let endTimer = self.endTimer
        stateLock.unlock()
        startTimer?.schedule(deadline: start)
        endTimer?.schedule(deadline: end)
        emitStatus(.active)
    }

    private func normalizeDelaySettings() {
        if delayMs < 0 { delayMs = 0 }
        if activationDelayMs < 0 { activationDelayMs = 0 }
    }

    private func handleConfigurationChange() {
        // Settings changes should affect future trigger events, not arm suppression immediately.
        if !isEnabled || delayMs == 0 {
            clearSuppressionWindow()
            emitStatus(.off)
        }
    }

    private func handleEnablementChange() {
        if isEnabled {
            if eventTap != nil {
                emitStatus(delayMs > 0 ? .active : .off)
            }
            return
        }
        clearSuppressionWindow()
        emitStatus(.off)
    }

    private func clearSuppressionWindow() {
        stateLock.lock()
        suppressionStart = nil
        suppressionEnd = nil
        stateLock.unlock()
    }

    private func emitStatus(_ status: Status) {
        if Thread.isMainThread {
            onStatusChange?(status)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onStatusChange?(status)
            }
        }
    }
}
