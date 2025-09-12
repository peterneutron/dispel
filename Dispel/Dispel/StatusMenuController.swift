import AppKit

final class StatusMenuController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let sliderItem = NSMenuItem()
    private let statusItemText = NSMenuItem()
    private let permissionItem = NSMenuItem()
    private let quitItem = NSMenuItem()

    private let slider = NSSlider(value: 200, minValue: 0, maxValue: 1000, target: nil, action: nil)
    private let sliderLabel = NSTextField(labelWithString: "Delay: 200 ms")

    // Advanced submenu: activation delay + trigger + blocking
    private let advancedItem = NSMenuItem(title: "Advanced", action: nil, keyEquivalent: "")
    private let advancedMenu = NSMenu()
    private let activationSliderItem = NSMenuItem()
    private let triggerParentItem = NSMenuItem(title: "Trigger", action: nil, keyEquivalent: "")
    private let triggerMenu = NSMenu()
    private let triggerKeyDownItem = NSMenuItem(title: "On Key Down", action: #selector(changeTrigger(_:)), keyEquivalent: "")
    private let triggerKeyUpItem = NSMenuItem(title: "On Key Up", action: #selector(changeTrigger(_:)), keyEquivalent: "")
    private let blockingParentItem = NSMenuItem(title: "Block Phases", action: nil, keyEquivalent: "")
    private let blockingMenu = NSMenu()
    private let blockDownItem = NSMenuItem(title: "Mouse Down", action: #selector(toggleBlockPhase(_:)), keyEquivalent: "")
    private let blockUpItem = NSMenuItem(title: "Mouse Up", action: #selector(toggleBlockPhase(_:)), keyEquivalent: "")
    private let activationSlider = NSSlider(value: 40, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let activationLabel = NSTextField(labelWithString: "Activation delay: 40 ms")

    var onEnableChanged: ((Bool) -> Void)?
    var onRequestAXPrompt: (() -> Void)?

    init(initialDelayMs: Int,
         initialActivationDelayMs: Int,
         initialTrigger: String,
         initialBlockMouseDown: Bool,
         initialBlockMouseUp: Bool,
         onDelayChanged: @escaping (Int) -> Void,
         onActivationDelayChanged: @escaping (Int) -> Void,
         onTriggerChanged: @escaping (String) -> Void,
         onBlockingChanged: @escaping (Bool, Bool) -> Void) {
        super.init()

        // Default icon; will be updated by updateStatus(_:)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.and.hand.point.up.left", accessibilityDescription: nil)
        statusItem.button?.imagePosition = .imageOnly

        // Slider view
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 6

        slider.numberOfTickMarks = 11
        slider.allowsTickMarkValuesOnly = true
        slider.target = self
        slider.action = #selector(sliderChanged)
        slider.minValue = 0
        slider.maxValue = 1000
        slider.intValue = Int32(initialDelayMs)

        sliderLabel.font = .systemFont(ofSize: 12)
        sliderLabel.textColor = .secondaryLabelColor
        sliderLabel.stringValue = "Delay: \(initialDelayMs) ms"

        container.addArrangedSubview(sliderLabel)
        container.addArrangedSubview(slider)

        let view = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 64))
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            container.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10)
        ])

        let customView = NSHostingMenuItemView(wrapped: view, size: view.frame.size)
        sliderItem.view = customView

        // Advanced submenu: Activation delay control
        let advContainer = NSStackView()
        advContainer.orientation = .vertical
        advContainer.alignment = .leading
        advContainer.spacing = 6

        activationSlider.numberOfTickMarks = 11
        activationSlider.allowsTickMarkValuesOnly = true
        activationSlider.target = self
        activationSlider.action = #selector(activationSliderChanged)
        activationSlider.minValue = 0
        activationSlider.maxValue = 100
        activationSlider.intValue = Int32(initialActivationDelayMs)

        activationLabel.font = .systemFont(ofSize: 12)
        activationLabel.textColor = .secondaryLabelColor
        activationLabel.stringValue = "Activation delay: \(initialActivationDelayMs) ms"

        advContainer.addArrangedSubview(activationLabel)
        advContainer.addArrangedSubview(activationSlider)

        let advView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 64))
        advContainer.translatesAutoresizingMaskIntoConstraints = false
        advView.addSubview(advContainer)
        NSLayoutConstraint.activate([
            advContainer.leadingAnchor.constraint(equalTo: advView.leadingAnchor, constant: 12),
            advContainer.trailingAnchor.constraint(equalTo: advView.trailingAnchor, constant: -12),
            advContainer.topAnchor.constraint(equalTo: advView.topAnchor, constant: 10),
            advContainer.bottomAnchor.constraint(equalTo: advView.bottomAnchor, constant: -10)
        ])

        activationSliderItem.view = NSHostingMenuItemView(wrapped: advView, size: advView.frame.size)

        // Trigger submenu setup
        triggerKeyDownItem.target = self; triggerKeyDownItem.tag = 0
        triggerKeyUpItem.target = self; triggerKeyUpItem.tag = 1
        triggerMenu.items = [triggerKeyDownItem, triggerKeyUpItem]
        triggerParentItem.submenu = triggerMenu

        // Blocking submenu setup
        blockDownItem.target = self; blockDownItem.state = initialBlockMouseDown ? .on : .off; blockDownItem.tag = 0
        blockUpItem.target = self; blockUpItem.state = initialBlockMouseUp ? .on : .off; blockUpItem.tag = 1
        blockingMenu.items = [blockDownItem, blockUpItem]
        blockingParentItem.submenu = blockingMenu

        // Apply initial trigger selection
        setTriggerMenuState(trigger: initialTrigger)

        advancedMenu.items = [triggerParentItem, blockingParentItem, .separator(), activationSliderItem]
        advancedItem.submenu = advancedMenu

        // Status line
        statusItemText.title = "Status: —"
        statusItemText.isEnabled = false

        // Permission prompt
        permissionItem.title = "Grant Accessibility Permission…"
        permissionItem.target = self
        permissionItem.action = #selector(requestAX)

        // Quit
        quitItem.title = "Quit Dispel"
        quitItem.target = self
        quitItem.action = #selector(quit)

        // Build menu
        menu.items = [sliderItem, advancedItem, .separator(), statusItemText, permissionItem, .separator(), quitItem]
        statusItem.menu = menu

        // Persist
        UserDefaults.standard.set(initialDelayMs, forKey: DefaultsKeys.delayMs)
        UserDefaults.standard.set(initialActivationDelayMs, forKey: DefaultsKeys.activationDelayMs)

        self.onDelayChanged = onDelayChanged
        self.onActivationDelayChanged = onActivationDelayChanged
        self.onTriggerChanged = onTriggerChanged
        self.onBlockingChanged = onBlockingChanged
        onDelayChanged(initialDelayMs)
        onActivationDelayChanged(initialActivationDelayMs)
        onTriggerChanged(initialTrigger)
        onBlockingChanged(initialBlockMouseDown, initialBlockMouseUp)
    }

    private var onDelayChanged: ((Int) -> Void)?
    private var onActivationDelayChanged: ((Int) -> Void)?
    private var onTriggerChanged: ((String) -> Void)?
    private var onBlockingChanged: ((Bool, Bool) -> Void)?

    func updateStatus(status: EventTapManager.Status) {
        statusItemText.title = "Status: \(status.rawValue)"
        // Icon rule:
        // - Off (trackpad not disabled) → filled symbol
        // - Anything else (Active/No Permission/Error) → outline symbol
        let symbolName: String = (status == .off)
            ? "rectangle.and.hand.point.up.left.fill"
            : "rectangle.and.hand.point.up.left"
        statusItem.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
    }

    func updateAXAuthorized(_ authorized: Bool) {
        permissionItem.isHidden = authorized
    }

    @objc private func sliderChanged() {
        // Snap to 100ms steps
        let step = 100
        let raw = Int(slider.intValue)
        let snapped = (raw + step / 2) / step * step
        slider.intValue = Int32(snapped)
        sliderLabel.stringValue = "Delay: \(snapped) ms"
        UserDefaults.standard.set(snapped, forKey: DefaultsKeys.delayMs)
        onDelayChanged?(snapped)
    }

    @objc private func activationSliderChanged() {
        // Snap to 10ms steps
        let step = 10
        let raw = Int(activationSlider.intValue)
        let snapped = (raw + step / 2) / step * step
        activationSlider.intValue = Int32(snapped)
        activationLabel.stringValue = "Activation delay: \(snapped) ms"
        UserDefaults.standard.set(snapped, forKey: DefaultsKeys.activationDelayMs)
        onActivationDelayChanged?(snapped)
    }

    // MARK: - Advanced: Trigger & Blocking
    @objc private func changeTrigger(_ sender: NSMenuItem) {
        // 0 = keyDown, 1 = keyUp
        let value = sender.tag == 0 ? "keyDown" : "keyUp"
        UserDefaults.standard.set(value, forKey: DefaultsKeys.trigger)
        setTriggerMenuState(trigger: value)
        onTriggerChanged?(value)
    }

    private func setTriggerMenuState(trigger: String) {
        let isDown = (trigger == "keyDown")
        triggerKeyDownItem.state = isDown ? .on : .off
        triggerKeyUpItem.state = isDown ? .off : .on
    }

    @objc private func toggleBlockPhase(_ sender: NSMenuItem) {
        if sender.tag == 0 {
            sender.state = sender.state == .on ? .off : .on
            UserDefaults.standard.set(sender.state == .on, forKey: DefaultsKeys.blockMouseDown)
        } else {
            sender.state = sender.state == .on ? .off : .on
            UserDefaults.standard.set(sender.state == .on, forKey: DefaultsKeys.blockMouseUp)
        }
        onBlockingChanged?(blockDownItem.state == .on, blockUpItem.state == .on)
    }

    @objc private func requestAX() { onRequestAXPrompt?() }

    @objc private func quit() { NSApp.terminate(nil) }
}

// Helper view wrapper for NSMenuItem custom view sizing
final class NSHostingMenuItemView: NSView {
    init(wrapped: NSView, size: NSSize) {
        super.init(frame: NSRect(origin: .zero, size: size))
        addSubview(wrapped)
        wrapped.frame = bounds
        wrapped.autoresizingMask = [.width, .height]
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
