import Carbon
import Cocoa

final class GlobalHotKeyRegistrar {
    private static let hotKeyIdentifier = EventHotKeyID(
        signature: OSType(0x43445853), // CDXS
        id: 1
    )

    private static let eventHandler: EventHandlerUPP = { _, _, userData in
        guard let userData else { return OSStatus(eventNotHandledErr) }
        let registrar = Unmanaged<GlobalHotKeyRegistrar>
            .fromOpaque(userData)
            .takeUnretainedValue()
        registrar.performAction()
        return noErr
    }

    private let action: () -> Void
    private var handlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?

    init(action: @escaping () -> Void) {
        self.action = action
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }

    deinit {
        unregister()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    @discardableResult
    func register(_ shortcut: GlobalShortcutDefinition?) -> Bool {
        unregister()
        guard let shortcut else { return true }
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            Self.hotKeyIdentifier,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            hotKeyRef = nil
        }
        return status == noErr
    }

    func unregister() {
        guard let hotKeyRef else { return }
        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
    }

    private func performAction() {
        DispatchQueue.main.async { [action] in
            action()
        }
    }
}

final class ShortcutRecordingHotKeyRegistrar {
    enum Action {
        case cancel
        case disable
        case capture(GlobalShortcutDefinition)
    }

    static let firstShortcutIdentifier: UInt32 = 100
    var onAction: ((Action) -> Void)?

    private static let signature = OSType(0x43445852) // CDXR

    private static let eventHandler: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else { return OSStatus(eventNotHandledErr) }
        let recorder = Unmanaged<ShortcutRecordingHotKeyRegistrar>
            .fromOpaque(userData)
            .takeUnretainedValue()
        return recorder.handle(event)
    }

    private var handlerRef: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var actions: [UInt32: Action] = [:]

    @discardableResult
    func start() -> Bool {
        stop()
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        guard status == noErr else { return false }

        register(keyCode: UInt32(kVK_Escape), modifiers: 0, identifier: 1, action: .cancel)
        register(keyCode: UInt32(kVK_Delete), modifiers: 0, identifier: 2, action: .disable)
        register(keyCode: UInt32(kVK_ForwardDelete), modifiers: 0, identifier: 3, action: .disable)
        for (offset, shortcut) in GlobalShortcutRules.recordingCandidates.enumerated() {
            register(
                keyCode: shortcut.keyCode,
                modifiers: shortcut.modifiers,
                identifier: Self.firstShortcutIdentifier + UInt32(offset),
                action: .capture(shortcut)
            )
        }
        return !hotKeyRefs.isEmpty
    }

    func stop() {
        hotKeyRefs.forEach { UnregisterEventHotKey($0) }
        hotKeyRefs.removeAll()
        actions.removeAll()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    private func handle(_ event: EventRef) -> OSStatus {
        var identifier = EventHotKeyID()
        guard GetEventParameter(
            event,
            OSType(kEventParamDirectObject),
            OSType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &identifier
        ) == noErr,
        identifier.signature == Self.signature,
        let action = actions[identifier.id] else {
            return OSStatus(eventNotHandledErr)
        }
        DispatchQueue.main.async { [weak self] in
            self?.onAction?(action)
        }
        return noErr
    }

    private func register(
        keyCode: UInt32,
        modifiers: UInt32,
        identifier: UInt32,
        action: Action
    ) {
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            EventHotKeyID(signature: Self.signature, id: identifier),
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr, let hotKeyRef else { return }
        hotKeyRefs.append(hotKeyRef)
        actions[identifier] = action
    }
}

final class GlobalShortcutMenuRowView: NSView {
    enum Role {
        case command
        case recorder
    }

    var onAction: (() -> Void)?
    var onRecordingRequested: (() -> Void)?

    private let role: Role
    private let rowTitle: String
    private let titleField = NSTextField(labelWithString: "")
    private let valueField = NSTextField(labelWithString: "")
    private let highlightView = NSVisualEffectView()
    private let rowHeight: CGFloat = 24
    private let titleInset: CGFloat = 22
    private let rightInset: CGFloat = 14
    private let valueWidth: CGFloat = 145
    private var shortcut: GlobalShortcutDefinition?
    private var hovered = false

    init(title: String, shortcut: GlobalShortcutDefinition?, role: Role, width: CGFloat) {
        self.role = role
        self.rowTitle = title
        self.shortcut = shortcut
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: rowHeight))
        autoresizingMask = [.width]
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(title)

        highlightView.material = .selection
        highlightView.state = .active
        highlightView.isEmphasized = true
        highlightView.wantsLayer = true
        highlightView.layer?.cornerRadius = 5
        highlightView.isHidden = true
        addSubview(highlightView)

        titleField.stringValue = title
        titleField.font = .menuFont(ofSize: 0)
        titleField.textColor = .labelColor
        titleField.lineBreakMode = .byTruncatingTail
        addSubview(titleField)

        valueField.font = .menuFont(ofSize: 0)
        valueField.textColor = .secondaryLabelColor
        valueField.alignment = .right
        addSubview(valueField)
        updateShortcutText()
        updateAccessibilityValue()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func accessibilityPerformPress() -> Bool {
        switch role {
        case .command:
            onAction?()
        case .recorder:
            onRecordingRequested?()
        }
        return true
    }

    func setShortcut(_ shortcut: GlobalShortcutDefinition?) {
        self.shortcut = shortcut
        updateShortcutText()
    }

    override func layout() {
        super.layout()
        highlightView.frame = bounds.insetBy(dx: 5, dy: 0)
        let textHeight: CGFloat = 18
        let textY = (bounds.height - textHeight) / 2
        valueField.frame = NSRect(
            x: bounds.width - rightInset - valueWidth,
            y: textY,
            width: valueWidth,
            height: textHeight
        )
        titleField.frame = NSRect(
            x: titleInset,
            y: textY,
            width: max(80, valueField.frame.minX - titleInset - 8),
            height: textHeight
        )
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
        updateHighlight()
    }

    override func mouseExited(with event: NSEvent) {
        hovered = false
        updateHighlight()
    }

    override func mouseDown(with event: NSEvent) {
        switch role {
        case .command:
            onAction?()
        case .recorder:
            onRecordingRequested?()
        }
    }

    private func updateShortcutText() {
        valueField.stringValue = shortcut?.displayText ?? (role == .recorder ? "Off" : "")
    }

    private func updateAccessibilityValue() {
        let shortcutValue = shortcut?.displayText ?? "Off"
        setAccessibilityValue(role == .command ? "\(rowTitle), \(shortcutValue)" : shortcutValue)
    }

    private func updateHighlight() {
        let selected = hovered
        highlightView.isHidden = !selected
        titleField.textColor = selected ? .white : .labelColor
        valueField.textColor = selected ? .white : .secondaryLabelColor
    }

}
