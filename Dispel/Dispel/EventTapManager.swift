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
    var delayMs: Int = 200 { didSet { if delayMs < 0 { delayMs = 0 }; restartSuppressionIfNeeded() } }
    var activationDelayMs: Int = 20 { didSet { if activationDelayMs < 0 { activationDelayMs = 0 }; restartSuppressionIfNeeded() } }
    var blockMouseDown: Bool = true
    var blockMouseUp: Bool = false
    var isEnabled: Bool = true { didSet { /* no-op; evaluated in callback */ } }

    // Callbacks
    var onStatusChange: ((Status) -> Void)?

    // Internal
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var startTimer: DispatchSourceTimer?
    private var endTimer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.dispel.timer")
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
            onStatusChange?(.noPermission)
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
            onStatusChange?(.error)
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let src = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            onStatusChange?(isEnabled && delayMs > 0 ? .active : .off)
        }

        configureTimers()
    }

    func stop() {
        startTimer?.cancel(); startTimer = nil
        endTimer?.cancel(); endTimer = nil
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
        }
        runLoopSource = nil
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        eventTap = nil
        onStatusChange?(.off)
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
        guard let start = suppressionStart, let end = suppressionEnd else { return false }
        let now = DispatchTime.now()
        return now >= start && now < end
    }

    private func configureTimers() {
        startTimer?.cancel(); startTimer = nil
        endTimer?.cancel(); endTimer = nil
        startTimer = DispatchSource.makeTimerSource(queue: timerQueue)
        endTimer = DispatchSource.makeTimerSource(queue: timerQueue)
        startTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            let end = self.suppressionEnd ?? (DispatchTime.now() + .milliseconds(self.delayMs))
            self.suppressionStart = DispatchTime.now()
            self.suppressionEnd = end
        }
        endTimer?.setEventHandler { [weak self] in
            self?.suppressionStart = nil
            self?.suppressionEnd = nil
            DispatchQueue.main.async { self?.onStatusChange?( (self?.isEnabled ?? false) && (self?.delayMs ?? 0) > 0 ? .active : .off ) }
        }
        startTimer?.resume()
        endTimer?.resume()
    }

    private func armSuppressionTimers() {
        let delay = max(0, delayMs)
        let activation = max(0, activationDelayMs)
        if delay == 0 { suppressionStart = nil; suppressionEnd = nil; return }
        configureTimers()
        let start = DispatchTime.now() + .milliseconds(activation)
        let end = start + .milliseconds(delay)
        suppressionStart = start
        suppressionEnd = end
        startTimer?.schedule(deadline: start)
        endTimer?.schedule(deadline: end)
        onStatusChange?(.active)
    }

    private func restartSuppressionIfNeeded() {
        if isEnabled && delayMs > 0 { armSuppressionTimers() } else { suppressionStart = nil; suppressionEnd = nil; onStatusChange?(.off) }
    }
}
