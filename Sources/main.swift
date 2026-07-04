import Cocoa
import Darwin

final class SessionRowView: NSView {
    let id: String
    var onClick: (() -> Void)?
    private let nameField = NSTextField(labelWithString: "")
    private let timerField = NSTextField(labelWithString: "")
    private let badgeView = NSImageView()
    private let highlightView = NSVisualEffectView()
    private let rowH: CGFloat = 24
    private let timerW: CGFloat = 74
    private let nameX: CGFloat = 30
    private let textY: CGFloat = 6
    private var hovered = false
    private var badgeNormal: NSImage?
    private var badgeSelected: NSImage?

    init(id: String, width: CGFloat) {
        self.id = id
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: rowH))
        autoresizingMask = [.width]

        highlightView.material = .selection
        highlightView.state = .active
        highlightView.isEmphasized = true
        highlightView.wantsLayer = true
        highlightView.layer?.cornerRadius = 5
        highlightView.isHidden = true
        addSubview(highlightView)

        nameField.font = .menuFont(ofSize: 0)
        nameField.textColor = .labelColor
        nameField.lineBreakMode = .byTruncatingTail
        nameField.frame = NSRect(x: nameX, y: textY, width: 150, height: 16)
        nameField.autoresizingMask = [.maxXMargin]
        addSubview(nameField)

        timerField.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuFont(ofSize: 0).pointSize - 2, weight: .regular)
        timerField.textColor = .secondaryLabelColor
        timerField.alignment = .right
        timerField.autoresizingMask = [.minXMargin]
        addSubview(timerField)

        badgeView.imageScaling = .scaleNone
        badgeView.autoresizingMask = [.minXMargin]
        addSubview(badgeView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(name: String, timer: String?, badgeNormal: NSImage?, badgeSelected: NSImage?,
                   badgeInset: CGFloat, timerGap: CGFloat) {
        let w = bounds.width
        nameField.stringValue = name

        self.badgeNormal = badgeNormal
        self.badgeSelected = badgeSelected
        let badge = hovered ? badgeSelected : badgeNormal
        var badgeLeft = w - badgeInset
        if let badge {
            badgeView.isHidden = false
            badgeView.image = badge
            badgeView.frame = NSRect(x: w - badgeInset - badge.size.width,
                                     y: (rowH - badge.size.height) / 2,
                                     width: badge.size.width,
                                     height: badge.size.height)
            badgeLeft = badgeView.frame.minX
        } else {
            badgeView.isHidden = true
        }

        if let timer {
            timerField.isHidden = false
            timerField.stringValue = timer
            timerField.frame = NSRect(x: badgeLeft - timerGap - timerW,
                                      y: textY,
                                      width: timerW,
                                      height: 16)
            nameField.frame.size.width = max(70, timerField.frame.minX - nameField.frame.minX - 8)
        } else {
            timerField.isHidden = true
            nameField.frame.size.width = max(120, badgeLeft - nameField.frame.minX - 8)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        setHover(true)
    }

    override func mouseExited(with event: NSEvent) {
        setHover(false)
    }

    private func setHover(_ value: Bool) {
        hovered = value
        highlightView.isHidden = !value
        nameField.textColor = value ? .white : .labelColor
        timerField.textColor = value ? .white : .secondaryLabelColor
        if !badgeView.isHidden {
            badgeView.image = value ? badgeSelected : badgeNormal
        }
    }

    override func layout() {
        super.layout()
        highlightView.frame = bounds.insetBy(dx: 5, dy: 0)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}

final class SessionGroupHeaderView: NSView {
    private let titleField = NSTextField(labelWithString: "")
    private let countField = NSTextField(labelWithString: "")
    private let rowH: CGFloat = 14
    private let titleX: CGFloat = 22
    private let rightPad: CGFloat = 14

    init(title: String, count: Int, width: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: rowH))
        autoresizingMask = [.width]

        titleField.stringValue = title
        titleField.font = .systemFont(ofSize: NSFont.menuFont(ofSize: 0).pointSize - 3, weight: .regular)
        titleField.textColor = .tertiaryLabelColor
        titleField.lineBreakMode = .byTruncatingTail
        titleField.allowsDefaultTighteningForTruncation = false
        addSubview(titleField)

        countField.stringValue = "\(count)"
        countField.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuFont(ofSize: 0).pointSize - 3, weight: .regular)
        countField.textColor = .tertiaryLabelColor
        countField.alignment = .right
        addSubview(countField)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let countW: CGFloat = 26
        countField.frame = NSRect(x: bounds.width - rightPad - countW,
                                  y: 0,
                                  width: countW,
                                  height: 14)
        titleField.frame = NSRect(x: titleX,
                                  y: 0,
                                  width: max(80, countField.frame.minX - titleX - 8),
                                  height: 14)
    }
}

final class MenuSectionHeaderView: NSView {
    private let titleField = NSTextField(labelWithString: "")
    private let rowH: CGFloat = 24
    private let titleX: CGFloat = 22

    init(title: String, width: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: rowH))
        autoresizingMask = [.width]

        titleField.stringValue = title
        titleField.font = .systemFont(ofSize: NSFont.menuFont(ofSize: 0).pointSize - 1, weight: .semibold)
        titleField.textColor = .secondaryLabelColor
        titleField.lineBreakMode = .byTruncatingTail
        addSubview(titleField)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        titleField.frame = NSRect(x: titleX,
                                  y: (rowH - 16) / 2,
                                  width: max(80, bounds.width - titleX - 14),
                                  height: 16)
    }
}

final class StatusController: NSObject, NSMenuDelegate {
    enum State: String {
        case idle
        case done
        case thinking
        case tool
        case compacting
        case permission
        case waiting
    }

    enum IconStyle: String {
        case codex
        case pet
    }

    struct PetAnimation {
        let row: Int
        let frames: Int
    }

    struct PetInfo {
        let id: String
        let displayName: String
        let spritesheetPath: String
    }

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let statusMenu = NSMenu()
    let defaultStateDir = (NSHomeDirectory() as NSString).appendingPathComponent(".codex/statusbar/state.d")
    let defaultLegacyStatePath = (NSHomeDirectory() as NSString).appendingPathComponent(".codex/statusbar/state.json")
    let defaultThreadMetadataPath = (NSHomeDirectory() as NSString).appendingPathComponent(".codex/state_5.sqlite")
    let pollInterval: TimeInterval = 0.4
    let autoExitDelay: TimeInterval = 20
    let defaultThreadName = "无法获取 thread 名称"

    var stateDir: String {
        ProcessInfo.processInfo.environment["CODEX_STATUSBAR_STATE_DIR"] ?? defaultStateDir
    }

    var legacyStatePath: String {
        ProcessInfo.processInfo.environment["CODEX_STATUSBAR_STATE_PATH"] ?? defaultLegacyStatePath
    }

    var threadMetadataPath: String {
        ProcessInfo.processInfo.environment["CODEX_STATUSBAR_THREAD_DB_PATH"] ?? defaultThreadMetadataPath
    }

    var pollTimer: Timer?
    var notNeededSince: Date?

    struct Session {
        struct FocusTarget {
            var kind: String
            var bundleId: String
            var appName: String
            var url: String
            var fallbackKind: String
            var fallbackBundleId: String
            var fallbackAppName: String

            init(object: [String: Any]?) {
                self.kind = object?["kind"] as? String ?? "none"
                self.bundleId = object?["bundleId"] as? String ?? ""
                self.appName = object?["appName"] as? String ?? ""
                self.url = object?["url"] as? String ?? ""
                let fallback = object?["fallback"] as? [String: Any]
                self.fallbackKind = fallback?["kind"] as? String ?? ""
                self.fallbackBundleId = fallback?["bundleId"] as? String ?? ""
                self.fallbackAppName = fallback?["appName"] as? String ?? ""
            }
        }

        var id: String
        var state: State
        var label: String
        var tool: String
        var threadName: String
        var project: String
        var sessionId: String
        var turnId: String
        var pid: Int32
        var entrypoint: String
        var entrypointSource: String
        var termProgram: String
        var focusTarget: FocusTarget
        var transcript: String
        var started: Bool
        var startedAt: Double
        var ts: Double
        var visibleUntilMs: Double
        var effectiveState: State

        init(json object: [String: Any], id: String) {
            self.id = id
            self.state = State(rawValue: object["state"] as? String ?? "idle") ?? .idle
            self.label = object["label"] as? String ?? ""
            self.tool = object["tool"] as? String ?? ""
            self.threadName = object["threadName"] as? String ?? ""
            self.project = object["project"] as? String ?? ""
            self.sessionId = object["sessionId"] as? String ?? id
            self.turnId = object["turnId"] as? String ?? ""
            self.pid = Int32(truncatingIfNeeded: (object["pid"] as? NSNumber)?.intValue ?? 0)
            self.entrypoint = object["entrypoint"] as? String ?? ""
            self.entrypointSource = object["entrypointSource"] as? String ?? ""
            self.termProgram = object["termProgram"] as? String ?? object["term_program"] as? String ?? ""
            self.focusTarget = FocusTarget(object: object["focusTarget"] as? [String: Any])
            self.transcript = object["transcript"] as? String ?? object["transcript_path"] as? String ?? ""
            self.started = object["started"] as? Bool ?? false
            self.startedAt = (object["startedAt"] as? NSNumber)?.doubleValue ?? 0
            self.ts = (object["ts"] as? NSNumber)?.doubleValue ?? 0
            self.visibleUntilMs = (object["visibleUntilMs"] as? NSNumber)?.doubleValue ?? 0
            self.effectiveState = self.state
        }
    }

    struct MenuSessionGroup {
        let name: String
        let sessions: [Session]
    }

    var sessions: [String: Session] = [:]
    var threadMetadata: [String: ThreadMetadata] = [:]
    lazy var threadMetadataStore = ThreadMetadataStore(sqlitePath: threadMetadataPath)
    var fileMTimes: [String: Date] = [:]
    var legacyMTime: Date = .distantPast
    var menuIsOpen = false
    var sessionMenuItems: [(item: NSMenuItem, id: String)] = []

    var hideIdleAfter: TimeInterval {
        UserDefaults.standard.object(forKey: "hideIdleAfter") as? Double ?? 1800
    }

    var activeLabel = ""
    var activeStartedAt: Double = 0
    var activeState: State = .idle
    var activeIconWarning = false
    var frameIndex = 0
    var lastLoggedSignature = ""

    var showTimer = true
    var showStatusText = true
    var playNotificationSounds = true
    var iconSystem = false
    var iconStyle: IconStyle = .codex
    var selectedPetId = ""
    lazy var pets: [PetInfo] = loadPets()
    var petImageCache: [String: NSImage] = [:]
    var lastSoundState: State = .idle
    lazy var installedCodexIcon: NSImage? = loadInstalledCodexIcon()
    lazy var installedCodexTemplateIcon: NSImage? = loadInstalledCodexTemplateIcon()

    let codexGreen = NSColor(srgbRed: 0.08, green: 0.72, blue: 0.48, alpha: 1)
    let blue = NSColor(srgbRed: 0.20, green: 0.48, blue: 0.92, alpha: 1)
    let amber = NSColor(srgbRed: 0.95, green: 0.70, blue: 0.16, alpha: 1)
    var longRunningToolIconTint: NSColor { amber }

    override init() {
        super.init()

        let defaults = UserDefaults.standard
        if defaults.object(forKey: "showTimer") != nil {
            showTimer = defaults.bool(forKey: "showTimer")
        }
        if defaults.object(forKey: "showStatusText") != nil {
            showStatusText = defaults.bool(forKey: "showStatusText")
        }
        if defaults.object(forKey: "playNotificationSounds") != nil {
            playNotificationSounds = defaults.bool(forKey: "playNotificationSounds")
        }
        if defaults.object(forKey: "iconSystem") != nil {
            iconSystem = defaults.bool(forKey: "iconSystem")
        }
        if let rawIconStyle = defaults.string(forKey: "iconStyle"),
           let savedIconStyle = IconStyle(rawValue: rawIconStyle) {
            iconStyle = savedIconStyle
        }
        selectedPetId = defaults.string(forKey: "selectedPetId") ?? ""

        statusMenu.delegate = self
        statusItem.menu = statusMenu
        statusItem.isVisible = true
        if let button = statusItem.button {
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = "Codex Status Bar"
        }

        render(state: .idle, label: "", startedAt: 0)
        cleanupSessionFilesOnStartup()

        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        tick()
        scheduleStartupHookRepair()
    }

    func menuWillOpen(_ menu: NSMenu) {
        menuIsOpen = true
    }

    func menuDidClose(_ menu: NSMenu) {
        menuIsOpen = false
        sessionMenuItems.removeAll()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        sessionMenuItems.removeAll()
        reloadSessions()
        refreshEffectiveSessionStates()

        addSessionsSection(to: menu)

        menu.addItem(header("Options"))
        let timerItem = NSMenuItem(title: "Show timer", action: #selector(toggleTimer), keyEquivalent: "")
        timerItem.target = self
        timerItem.state = showTimer ? .on : .off
        menu.addItem(timerItem)

        let statusTextItem = NSMenuItem(title: "Show status text", action: #selector(toggleStatusText), keyEquivalent: "")
        statusTextItem.target = self
        statusTextItem.state = showStatusText ? .on : .off
        menu.addItem(statusTextItem)

        let soundsItem = NSMenuItem(title: "Play notification sounds", action: #selector(toggleNotificationSounds), keyEquivalent: "")
        soundsItem.target = self
        soundsItem.state = playNotificationSounds ? .on : .off
        menu.addItem(soundsItem)

        let hideParent = NSMenuItem(title: "Hide idle sessions", action: nil, keyEquivalent: "")
        let hideMenu = NSMenu()
        for (title, seconds) in [("5 minutes", 300.0), ("15 minutes", 900.0), ("30 minutes", 1800.0), ("1 hour", 3600.0), ("Never", 0.0)] {
            let item = NSMenuItem(title: title, action: #selector(chooseHideIdle(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = seconds
            item.state = hideIdleAfter == seconds ? .on : .off
            hideMenu.addItem(item)
        }
        hideParent.submenu = hideMenu
        menu.addItem(hideParent)

        menu.addItem(.separator())

        menu.addItem(header("Icon"))
        let colorItem = NSMenuItem(title: "Use system icon color", action: #selector(toggleIconColor), keyEquivalent: "")
        colorItem.target = self
        colorItem.state = iconSystem ? .on : .off
        menu.addItem(colorItem)

        let iconStyleItem = NSMenuItem(title: "Icon Style", action: nil, keyEquivalent: "")
        let iconStyleMenu = NSMenu()
        let codexItem = NSMenuItem(title: "Codex", action: #selector(useCodexIconStyle), keyEquivalent: "")
        codexItem.target = self
        codexItem.state = iconStyle == .codex ? .on : .off
        iconStyleMenu.addItem(codexItem)
        let petItem = NSMenuItem(title: "Pet", action: #selector(usePetIconStyle), keyEquivalent: "")
        petItem.target = self
        petItem.state = iconStyle == .pet ? .on : .off
        iconStyleMenu.addItem(petItem)
        iconStyleItem.submenu = iconStyleMenu
        menu.addItem(iconStyleItem)

        if !pets.isEmpty {
            let petsItem = NSMenuItem(title: "Pet", action: nil, keyEquivalent: "")
            let petsMenu = NSMenu()
            for pet in pets {
                let item = NSMenuItem(title: pet.displayName, action: #selector(selectPet(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = pet.id
                item.state = effectivePet()?.id == pet.id ? .on : .off
                petsMenu.addItem(item)
            }
            petsItem.submenu = petsMenu
            menu.addItem(petsItem)
        }

        menu.addItem(.separator())
        menu.addItem(header("Diagnostics"))

        let revealItem = NSMenuItem(title: "Reveal State Directory", action: #selector(revealStateFile), keyEquivalent: "")
        revealItem.target = self
        menu.addItem(revealItem)

        let resetItem = NSMenuItem(title: "Reset Status", action: #selector(resetStatus), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        let countItem = NSMenuItem(title: "Sessions: \(sessions.count)", action: nil, keyEquivalent: "")
        countItem.isEnabled = false
        menu.addItem(countItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Codex Status Bar", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    func header(_ title: String) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = MenuSectionHeaderView(title: title, width: 310)
        return item
    }

    func addSessionsSection(to menu: NSMenu) {
        menu.addItem(header("Sessions"))
        let visible = visibleMenuSessions()
        if visible.isEmpty {
            let empty = NSMenuItem(title: "No active Codex sessions", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for group in groupedMenuSessions(visible) {
                let headerView = SessionGroupHeaderView(title: group.name, count: group.sessions.count, width: 310)
                let headerItem = NSMenuItem()
                headerItem.view = headerView
                menu.addItem(headerItem)

                for session in group.sessions {
                    let row = SessionRowView(id: session.id, width: 310)
                    configureSessionRow(row, session)
                    let item = NSMenuItem()
                    item.view = row
                    row.onClick = { [weak self, weak menu] in
                        menu?.cancelTracking()
                        self?.openSession(session)
                    }
                    menu.addItem(item)
                    sessionMenuItems.append((item, session.id))
                }
            }
        }
        menu.addItem(.separator())
    }

    @objc func toggleTimer() {
        showTimer.toggle()
        UserDefaults.standard.set(showTimer, forKey: "showTimer")
        applyTitle()
    }

    @objc func toggleStatusText() {
        showStatusText.toggle()
        UserDefaults.standard.set(showStatusText, forKey: "showStatusText")
        applyTitle()
    }

    @objc func toggleNotificationSounds() {
        playNotificationSounds.toggle()
        UserDefaults.standard.set(playNotificationSounds, forKey: "playNotificationSounds")
    }

    @objc func toggleIconColor() {
        iconSystem.toggle()
        UserDefaults.standard.set(iconSystem, forKey: "iconSystem")
        render(state: activeState, label: activeLabel, startedAt: activeStartedAt, iconWarning: activeIconWarning)
    }

    @objc func chooseHideIdle(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? Double else { return }
        UserDefaults.standard.set(seconds, forKey: "hideIdleAfter")
    }

    @objc func useCodexIconStyle() {
        setIconStyle(.codex)
    }

    @objc func usePetIconStyle() {
        setIconStyle(.pet)
    }

    func setIconStyle(_ style: IconStyle) {
        iconStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: "iconStyle")
        render(state: activeState, label: activeLabel, startedAt: activeStartedAt, iconWarning: activeIconWarning)
    }

    @objc func selectPet(_ sender: NSMenuItem) {
        guard let petId = sender.representedObject as? String else { return }
        selectedPetId = petId
        iconStyle = .pet
        UserDefaults.standard.set(petId, forKey: "selectedPetId")
        UserDefaults.standard.set(IconStyle.pet.rawValue, forKey: "iconStyle")
        render(state: activeState, label: activeLabel, startedAt: activeStartedAt, iconWarning: activeIconWarning)
    }

    @objc func revealStateFile() {
        try? FileManager.default.createDirectory(atPath: stateDir, withIntermediateDirectories: true)
        let url = URL(fileURLWithPath: stateDir)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc func resetStatus() {
        for file in stateFileNames() {
            try? FileManager.default.removeItem(atPath: (stateDir as NSString).appendingPathComponent(file))
        }
        try? FileManager.default.removeItem(atPath: legacyStatePath)
        sessions.removeAll()
        fileMTimes.removeAll()
        legacyMTime = .distantPast
        render(state: .idle, label: "", startedAt: 0)
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    func tick() {
        reloadSessions()
        refreshThreadMetadata()
        applyArchivedThreadOverlay()
        evaluate()
        evaluateAutoExit()
        if menuIsOpen {
            refreshOpenMenuRows()
        }
    }

    func stateFileNames() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: stateDir)) ?? []).filter { $0.hasSuffix(".json") }
    }

    func reloadSessions() {
        let files = stateFileNames()
        if files.isEmpty {
            loadLegacyStateIfNeeded()
            threadMetadata.removeAll()
            return
        }

        if sessions.keys.contains("legacy-state") {
            sessions["legacy-state"] = nil
            legacyMTime = .distantPast
        }

        let present = Set(files)
        for key in Array(fileMTimes.keys) where !present.contains(key) {
            fileMTimes[key] = nil
            sessions[(key as NSString).deletingPathExtension] = nil
        }

        let fm = FileManager.default
        for file in files {
            let fullPath = (stateDir as NSString).appendingPathComponent(file)
            guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                  let mtime = attrs[.modificationDate] as? Date else { continue }
            if fileMTimes[file] == mtime { continue }
            fileMTimes[file] = mtime
            guard let data = fm.contents(atPath: fullPath),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                removeCorruptSessionFile(file)
                continue
            }
            let id = (file as NSString).deletingPathExtension
            sessions[id] = Session(json: object, id: id)
        }
    }

    func refreshThreadMetadata() {
        let ids = sessions.values.map { $0.sessionId.isEmpty ? $0.id : $0.sessionId }
        threadMetadata = threadMetadataStore.metadata(for: ids)
    }

    func applyArchivedThreadOverlay() {
        for session in sessions.values where isArchivedThread(session) && isActiveState(session.state) {
            markArchivedSessionDone(session)
        }
    }

    func isArchivedThread(_ session: Session) -> Bool {
        let id = session.sessionId.isEmpty ? session.id : session.sessionId
        return threadMetadata[id]?.archived == true
    }

    func isActiveState(_ state: State) -> Bool {
        switch state {
        case .thinking, .tool, .compacting, .permission, .waiting:
            return true
        case .idle, .done:
            return false
        }
    }

    func statePathForSession(_ id: String) -> String {
        (stateDir as NSString).appendingPathComponent(id + ".json")
    }

    func markArchivedSessionDone(_ session: Session) {
        guard session.id != "legacy-state" else { return }
        let path = statePathForSession(session.id)
        guard let data = FileManager.default.contents(atPath: path),
              var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return
        }

        let now = Date().timeIntervalSince1970
        object["state"] = State.done.rawValue
        object["label"] = "Done"
        object["tool"] = ""
        object["turnId"] = ""
        object["started"] = false
        object["startedAt"] = 0
        object["ts"] = now

        guard let output = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }

        let tmp = path + ".\(ProcessInfo.processInfo.processIdentifier).tmp"
        do {
            try output.write(to: URL(fileURLWithPath: tmp), options: .atomic)
            _ = try FileManager.default.replaceItemAt(URL(fileURLWithPath: path),
                                                       withItemAt: URL(fileURLWithPath: tmp),
                                                       backupItemName: nil,
                                                       options: [])
            var updated = Session(json: object, id: session.id)
            updated.effectiveState = .done
            sessions[session.id] = updated
            if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
               let mtime = attrs[.modificationDate] as? Date {
                fileMTimes[session.id + ".json"] = mtime
            }
        } catch {
            try? FileManager.default.removeItem(atPath: tmp)
        }
    }

    func loadLegacyStateIfNeeded() {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: legacyStatePath),
              let mtime = attrs[.modificationDate] as? Date else {
            sessions.removeAll()
            fileMTimes.removeAll()
            legacyMTime = .distantPast
            return
        }

        guard mtime != legacyMTime else { return }
        legacyMTime = mtime
        fileMTimes.removeAll()
        sessions.removeAll()
        if let data = fm.contents(atPath: legacyStatePath),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            sessions["legacy-state"] = Session(json: object, id: "legacy-state")
        }
    }

    func evaluate() {
        refreshEffectiveSessionStates()
        cleanupDeadSessions()

        let displaySessions = sessions.values.filter { !isArchivedThread($0) }
        guard let lead = displaySessions.max(by: { left, right in
            let leftPriority = priority(of: left.effectiveState)
            let rightPriority = priority(of: right.effectiveState)
            return leftPriority == rightPriority ? left.ts < right.ts : leftPriority < rightPriority
        }) else {
            logRender(state: .idle, label: "", startedAt: 0)
            render(state: .idle, label: "", startedAt: 0)
            return
        }

        let state = lead.effectiveState
        let label = statusLabel(for: lead)
        let startedAt = state == .thinking || state == .tool || state == .compacting ? lead.startedAt : 0
        let iconWarning = isLongRunningTool(lead)

        switch state {
        case .thinking:
            logRender(state: .thinking, label: label, startedAt: startedAt)
            render(state: .thinking, label: label.isEmpty ? "Thinking..." : label, startedAt: startedAt)
        case .tool:
            logRender(state: .tool, label: label, startedAt: startedAt)
            render(state: .tool, label: label.isEmpty ? "Working..." : label, startedAt: startedAt, iconWarning: iconWarning)
        case .compacting:
            logRender(state: .compacting, label: label, startedAt: startedAt)
            render(state: .compacting, label: label.isEmpty ? "Compacting" : label, startedAt: startedAt)
        case .permission:
            logRender(state: .permission, label: label, startedAt: 0)
            render(state: .permission, label: label.isEmpty ? "Awaiting permission" : label, startedAt: 0)
        case .waiting:
            logRender(state: .waiting, label: label, startedAt: 0)
            render(state: .waiting, label: label.isEmpty ? "Waiting" : label, startedAt: 0)
        case .done:
            logRender(state: .done, label: "", startedAt: 0)
            render(state: .done, label: "", startedAt: 0)
        case .idle:
            logRender(state: .idle, label: "", startedAt: 0)
            render(state: .idle, label: "", startedAt: 0)
        }
    }

    func refreshEffectiveSessionStates() {
        let now = Date().timeIntervalSince1970
        let codexRunning = codexDesktopProcessExists()
        for id in Array(sessions.keys) {
            guard var session = sessions[id] else { continue }
            session.effectiveState = effectiveState(for: session, now: now, codexRunning: codexRunning)
            sessions[id] = session
        }
    }

    func cleanupSessionFilesOnStartup() {
        try? FileManager.default.createDirectory(atPath: stateDir, withIntermediateDirectories: true)
        let now = Date().timeIntervalSince1970
        let codexRunning = codexDesktopProcessExists()
        let fm = FileManager.default
        for file in stateFileNames() {
            let fullPath = (stateDir as NSString).appendingPathComponent(file)
            guard let data = fm.contents(atPath: fullPath),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                removeCorruptSessionFile(file)
                continue
            }
            let session = Session(json: object, id: (file as NSString).deletingPathExtension)
            if shouldRemoveSession(session, now: now, codexRunning: codexRunning) {
                removeDeadSession(session.id)
                continue
            }
        }
    }

    func cleanupDeadSessions() {
        let now = Date().timeIntervalSince1970
        let codexRunning = codexDesktopProcessExists()
        for session in sessions.values {
            if isArchivedThread(session) { continue }
            if shouldRemoveSession(session, now: now, codexRunning: codexRunning) {
                removeDeadSession(session.id)
            }
        }
    }

    func shouldRemoveSession(_ session: Session, now: Double, codexRunning: Bool) -> Bool {
        let isDesktop = isDesktopSession(session)
        let livePid = session.pid > 0 && pidAlive(session.pid)
        return SessionStateRules.shouldRemoveSession(
            state: session.state.rawValue,
            effectiveState: session.effectiveState.rawValue,
            pid: session.pid,
            pidAlive: livePid,
            isDesktop: isDesktop,
            codexRunning: codexRunning,
            ts: session.ts,
            now: now,
            restingSessionPruneAfter: hideIdleAfter
        )
    }

    func removeCorruptSessionFile(_ file: String) {
        try? FileManager.default.removeItem(atPath: (stateDir as NSString).appendingPathComponent(file))
        fileMTimes[file] = nil
        sessions[(file as NSString).deletingPathExtension] = nil
    }

    func removeDeadSession(_ id: String) {
        try? FileManager.default.removeItem(atPath: (stateDir as NSString).appendingPathComponent(id + ".json"))
        sessions[id] = nil
        fileMTimes[id + ".json"] = nil
    }

    func visibleMenuSessions() -> [Session] {
        refreshEffectiveSessionStates()
        let now = Date().timeIntervalSince1970
        let ordered = sessions.values.filter { !isArchivedThread($0) }.sorted { left, right in
            let leftPriority = priority(of: left.effectiveState)
            let rightPriority = priority(of: right.effectiveState)
            return leftPriority == rightPriority ? left.ts > right.ts : leftPriority > rightPriority
        }

        let filtered = ordered.filter { session in
            let resting = priority(of: session.effectiveState) == 0
            return !(hideIdleAfter > 0 && resting && now - session.ts > hideIdleAfter)
        }
        return filtered.isEmpty ? Array(ordered.prefix(1)) : filtered
    }

    func groupedMenuSessions(_ visible: [Session]) -> [MenuSessionGroup] {
        var order: [String] = []
        var grouped: [String: [Session]] = [:]

        for session in visible {
            let name = sessionGroupName(for: session)
            if grouped[name] == nil {
                order.append(name)
                grouped[name] = []
            }
            grouped[name]?.append(session)
        }

        return order.map { MenuSessionGroup(name: $0, sessions: grouped[$0] ?? []) }
    }

    func sessionGroupName(for session: Session) -> String {
        let project = session.project.trimmingCharacters(in: .whitespacesAndNewlines)
        return project.isEmpty ? "Other" : project
    }

    func refreshOpenMenuRows() {
        refreshEffectiveSessionStates()
        for (item, id) in sessionMenuItems {
            guard let session = sessions[id], let row = item.view as? SessionRowView else { continue }
            configureSessionRow(row, session)
        }
    }

    func configureSessionRow(_ row: SessionRowView, _ session: Session) {
        let tag = surfaceTag(for: session)
        let running = sessionBadgeIsRunning(session)
        row.configure(name: truncated(sessionName(for: session), max: 24, keep: 23),
                      timer: sessionTimer(for: session),
                      badgeNormal: tag.isEmpty ? nil : badgeImage(tag, running: running),
                      badgeSelected: tag.isEmpty ? nil : badgeImage(tag, selected: true),
                      badgeInset: 12,
                      timerGap: 10)
    }

    func sessionName(for session: Session) -> String {
        let threadName = session.threadName.trimmingCharacters(in: .whitespacesAndNewlines)
        return threadName.isEmpty ? defaultThreadName : threadName
    }

    func sessionTimer(for session: Session) -> String? {
        guard (session.effectiveState == .thinking || session.effectiveState == .tool || session.effectiveState == .compacting), session.startedAt > 0 else {
            return nil
        }
        return elapsed(max(0, Int(Date().timeIntervalSince1970 - session.startedAt)))
    }

    func isLongRunningTool(_ session: Session, now: Double = Date().timeIntervalSince1970) -> Bool {
        SessionStateRules.isLongRunningTool(state: session.effectiveState.rawValue, ts: session.ts, now: now)
    }

    func sessionBadgeIsRunning(_ session: Session) -> Bool {
        session.effectiveState == .thinking || session.effectiveState == .tool || session.effectiveState == .compacting
    }

    func surfaceTag(for session: Session) -> String {
        let target = focusTarget(for: session)
        if target.kind == "bundle" || target.kind == "url" {
            return "APP"
        }
        if target.kind == "app" || session.entrypoint == "cli" || !session.termProgram.isEmpty {
            return "CLI"
        }
        return ""
    }

    func badgeImage(_ text: String, running: Bool = false, selected: Bool = false) -> NSImage {
        let string = text as NSString
        let font = NSFont.monospacedSystemFont(ofSize: 9.5, weight: .semibold)
        let pad: CGFloat = 7
        let height: CGFloat = 15
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let bg: NSColor
        let fg: NSColor
        if selected {
            bg = NSColor.white.withAlphaComponent(0.22)
            fg = .white
        } else if running {
            bg = .controlAccentColor
            fg = .white
        } else {
            bg = (dark ? NSColor.white : NSColor.black).withAlphaComponent(dark ? 0.14 : 0.10)
            fg = .secondaryLabelColor
        }
        let width = ceil(string.size(withAttributes: [.font: font]).width) + pad * 2
        return NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            bg.setFill()
            NSBezierPath(roundedRect: rect, xRadius: height / 2, yRadius: height / 2).fill()
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: fg]
            let textSize = string.size(withAttributes: attrs)
            string.draw(at: NSPoint(x: (rect.width - textSize.width) / 2,
                                    y: (rect.height - textSize.height) / 2 - 1),
                        withAttributes: attrs)
            return true
        }
    }

    func symbolImage(_ name: String, tint: NSColor? = nil) -> NSImage? {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
        if let tint {
            return image.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [tint]))
        }
        image.isTemplate = true
        return image
    }

    func truncated(_ value: String, max: Int, keep: Int) -> String {
        value.count > max ? String(value.prefix(keep)) + "..." : value
    }

    func elapsed(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let rest = seconds % 60
        return minutes > 0 ? "\(minutes)m \(rest)s" : "\(rest)s"
    }

    func openSession(_ session: Session) {
        let target = focusTarget(for: session)
        switch target.kind {
        case "url":
            openURLTarget(target)
        case "bundle":
            openCodex(bundleId: target.bundleId)
        case "app":
            openApplication(named: target.appName)
        default:
            break
        }
    }

    func focusTarget(for session: Session) -> Session.FocusTarget {
        if session.focusTarget.kind != "none" {
            return session.focusTarget
        }
        let surface = session.entrypoint.lowercased()
        if surface == "codex-desktop" || surface == "desktop" || surface == "app" {
            return desktopThreadTarget(for: session)
        }
        if surface == "cli", !session.termProgram.isEmpty {
            return Session.FocusTarget(object: ["kind": "app", "appName": terminalAppName(for: session.termProgram)])
        }
        if isCodexDesktopProcess(pid: session.pid) {
            return desktopThreadTarget(for: session)
        }
        return Session.FocusTarget(object: ["kind": "none"])
    }

    func desktopThreadTarget(for session: Session) -> Session.FocusTarget {
        let threadId = session.sessionId.isEmpty ? session.id : session.sessionId
        guard !threadId.isEmpty else {
            return Session.FocusTarget(object: ["kind": "bundle", "bundleId": "com.openai.codex"])
        }
        return Session.FocusTarget(object: [
            "kind": "url",
            "url": "codex://threads/\(threadId)",
            "fallback": ["kind": "bundle", "bundleId": "com.openai.codex"],
        ])
    }

    func isDesktopSession(_ session: Session) -> Bool {
        if session.focusTarget.kind == "bundle" || session.focusTarget.kind == "url" {
            return true
        }
        let surface = session.entrypoint.lowercased()
        if surface == "codex-desktop" || surface == "desktop" || surface == "app" {
            return true
        }
        return isCodexDesktopProcess(pid: session.pid)
    }

    func openCodex(bundleId: String = "com.openai.codex") {
        let workspace = NSWorkspace.shared
        if let url = workspace.urlForApplication(withBundleIdentifier: bundleId.isEmpty ? "com.openai.codex" : bundleId) {
            workspace.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        } else {
            workspace.open(URL(fileURLWithPath: "/Applications/Codex.app"))
        }
    }

    func openURLTarget(_ target: Session.FocusTarget) {
        if let url = URL(string: target.url), NSWorkspace.shared.open(url) {
            return
        }
        openFallbackTarget(target)
    }

    func openFallbackTarget(_ target: Session.FocusTarget) {
        switch target.fallbackKind {
        case "bundle":
            openCodex(bundleId: target.fallbackBundleId)
        case "app":
            openApplication(named: target.fallbackAppName)
        default:
            openCodex()
        }
    }

    func terminalAppName(for termProgram: String) -> String {
        switch termProgram {
        case "Apple_Terminal":
            return "Terminal"
        case "iTerm.app":
            return "iTerm"
        case "WarpTerminal":
            return "Warp"
        case "vscode":
            return "Visual Studio Code"
        default:
            return termProgram
        }
    }

    func openApplication(named app: String) {
        guard !app.isEmpty else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", app]
        try? process.run()
    }

    func isCodexDesktopProcess(pid: Int32) -> Bool {
        let command = processCommand(pid: pid)
        return command.contains("/Applications/Codex.app/")
            || command.contains("Codex.app/Contents/Resources/codex app-server")
    }

    func processCommand(pid: Int32) -> String {
        guard pid > 0 else { return "" }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", String(pid), "-o", "command="]
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return ""
        }
    }

    func scheduleStartupHookRepair() {
        guard ProcessInfo.processInfo.environment["CODEX_STATUSBAR_DISABLE_SELF_REPAIR"] != "1" else { return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.runHookInstaller()
        }
    }

    func installerPath() -> String {
        (Bundle.main.resourcePath ?? "").appending("/install-codex-statusbar.js")
    }

    func runHookInstaller() {
        let installer = installerPath()
        guard FileManager.default.fileExists(atPath: installer),
              let node = nodePathForInstaller() else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: node)
        process.arguments = [installer]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        if (try? process.run()) != nil {
            process.waitUntilExit()
        }
    }

    func nodePathForInstaller() -> String? {
        let env = ProcessInfo.processInfo.environment
        var candidates: [String] = []
        if let volta = env["VOLTA_HOME"] {
            candidates.append((volta as NSString).appendingPathComponent("bin/node"))
        }
        candidates.append((NSHomeDirectory() as NSString).appendingPathComponent(".volta/bin/node"))
        if let asdf = env["ASDF_DIR"] {
            candidates.append((asdf as NSString).appendingPathComponent("shims/node"))
        }
        candidates.append((NSHomeDirectory() as NSString).appendingPathComponent(".asdf/shims/node"))
        candidates.append(contentsOf: nvmNodeCandidates())
        candidates.append("/opt/homebrew/bin/node")
        candidates.append("/usr/local/bin/node")
        candidates.append("/usr/bin/node")
        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }
        return pathFromEnv("node")
    }

    func nvmNodeCandidates() -> [String] {
        let versionsDir = (NSHomeDirectory() as NSString).appendingPathComponent(".nvm/versions/node")
        guard let versions = try? FileManager.default.contentsOfDirectory(atPath: versionsDir) else { return [] }
        return versions.sorted().reversed().map {
            ((versionsDir as NSString).appendingPathComponent($0) as NSString).appendingPathComponent("bin/node")
        }
    }

    func pathFromEnv(_ executable: String) -> String? {
        for dir in (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":") {
            let candidate = (String(dir) as NSString).appendingPathComponent(executable)
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    func pidAlive(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        return kill(pid, 0) == 0 || errno == EPERM
    }

    func hasLiveSession() -> Bool {
        sessions.values.contains { session in
            if isArchivedThread(session) {
                return false
            }
            if [.permission, .tool, .thinking, .compacting, .waiting].contains(session.effectiveState) {
                return true
            }
            return !isDesktopSession(session) && session.pid > 0 && pidAlive(session.pid)
        }
    }

    func codexDesktopProcessExists() -> Bool {
        NSWorkspace.shared.runningApplications.contains { application in
            if application.bundleIdentifier == "com.openai.codex" {
                return true
            }
            if application.bundleURL?.path.contains("/Codex.app") == true {
                return true
            }
            return application.localizedName == "Codex"
        }
    }

    func evaluateAutoExit() {
        guard ProcessInfo.processInfo.environment["CODEX_STATUSBAR_DISABLE_AUTO_EXIT"] != "1" else { return }
        if codexDesktopProcessExists() || hasLiveSession() {
            notNeededSince = nil
            return
        }

        let now = Date()
        if notNeededSince == nil {
            notNeededSince = now
            return
        }
        if let since = notNeededSince, now.timeIntervalSince(since) > autoExitDelay {
            NSApp.terminate(nil)
        }
    }

    func effectiveState(for session: Session, now: Double, codexRunning: Bool) -> State {
        let isDesktop = isDesktopSession(session)
        let hasLivePid = !isDesktop && session.pid > 0 && pidAlive(session.pid)
        let state = SessionStateRules.effectiveState(SessionStateRuleInput(
            state: session.state.rawValue,
            startedAt: session.startedAt,
            ts: session.ts,
            isDesktop: isDesktop,
            codexRunning: codexRunning,
            hasLivePid: hasLivePid,
            interruptedByUser: transcriptShowsUserInterrupt(session.transcript),
            now: now
        ))
        return State(rawValue: state) ?? session.state
    }

    func transcriptShowsUserInterrupt(_ path: String) -> Bool {
        guard !path.isEmpty, let line = lastTurnLine(ofFileAt: path) else { return false }
        return TranscriptStateRules.lineShowsUserInterrupt(line)
    }

    func lastTurnLine(ofFileAt path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let chunk: UInt64 = 8192
        try? handle.seek(toOffset: size > chunk ? size - chunk : 0)
        guard let data = try? handle.readToEnd(),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return text
            .split(separator: "\n")
            .reversed()
            .map(String.init)
            .first { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return false }
                return !trimmed.contains("\"type\":\"system\"") &&
                    !trimmed.contains("\"type\":\"away_summary\"") &&
                    !trimmed.contains("\"type\":\"last-prompt\"") &&
                    !trimmed.contains("\"type\":\"ai-title\"") &&
                    !trimmed.contains("\"type\":\"mode\"") &&
                    !trimmed.contains("\"type\":\"permission-mode\"")
            }
    }

    func priority(of state: State) -> Int {
        switch state {
        case .permission:
            return 2
        case .thinking, .tool, .compacting:
            return 1
        case .idle, .done, .waiting:
            return 0
        }
    }

    func statusLabel(for session: Session) -> String {
        switch session.effectiveState {
        case .thinking:
            return session.label.isEmpty ? "Thinking..." : session.label
        case .tool:
            return session.label.isEmpty ? "Working..." : session.label
        case .compacting:
            return session.label.isEmpty ? "Compacting" : session.label
        case .permission:
            return session.label.isEmpty ? "Awaiting permission" : session.label
        case .waiting:
            return session.label.isEmpty ? "Waiting" : session.label
        case .idle, .done:
            return ""
        }
    }

    func logRender(state: State, label: String, startedAt: Double) {
        let signature = "\(state.rawValue)|\(label)|\(Int(startedAt))"
        guard signature != lastLoggedSignature else { return }
        lastLoggedSignature = signature
        let dir = (NSHomeDirectory() as NSString).appendingPathComponent(".codex/statusbar")
        let path = (dir as NSString).appendingPathComponent("app.log")
        let line = "\(ISO8601DateFormatter().string(from: Date())) render state=\(state.rawValue) label=\(label) startedAt=\(Int(startedAt)) stateDir=\(stateDir) legacyStatePath=\(legacyStatePath)\n"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: path),
               let handle = FileHandle(forWritingAtPath: path) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            } else {
                try? data.write(to: URL(fileURLWithPath: path))
            }
        }
    }

    func render(state: State, label: String, startedAt: Double, iconWarning: Bool = false) {
        playSoundIfNeeded(for: state)
        activeState = state
        activeLabel = label
        activeStartedAt = startedAt
        activeIconWarning = iconWarning

        statusItem.isVisible = true
        frameIndex = 0
        statusItem.button?.image = icon(for: state, frame: frameIndex)
        applyTitle()
    }

    func playSoundIfNeeded(for state: State) {
        guard state != lastSoundState else { return }
        lastSoundState = state
        guard playNotificationSounds else { return }

        switch state {
        case .permission:
            playSystemSound(named: "Ping")
        case .done:
            playSystemSound(named: "Glass")
        case .idle, .thinking, .tool, .compacting, .waiting:
            return
        }
    }

    func playSystemSound(named name: String) {
        NSSound(named: NSSound.Name(name))?.play()
    }

    func applyTitle() {
        guard let button = statusItem.button else { return }
        var text = activeLabel

        if !showStatusText {
            statusItem.length = NSStatusItem.squareLength
            button.imagePosition = .imageOnly
            button.attributedTitle = NSAttributedString(string: "")
            return
        }

        if showTimer, activeStartedAt > 0 {
            let seconds = max(0, Int(Date().timeIntervalSince1970 - activeStartedAt))
            let minutes = seconds / 60
            let rest = seconds % 60
            text += "  " + (minutes > 0 ? "\(minutes)m \(rest)s" : "\(rest)s")
        }

        if text.isEmpty {
            statusItem.length = NSStatusItem.squareLength
            button.imagePosition = .imageOnly
            button.attributedTitle = NSAttributedString(string: "")
            return
        }

        statusItem.length = NSStatusItem.variableLength
        button.imagePosition = .imageLeading
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular),
        ]
        button.attributedTitle = NSAttributedString(string: " \(text)", attributes: attrs)
    }

    func icon(for state: State, frame: Int) -> NSImage {
        let color: NSColor?
        switch state {
        case .permission:
            color = amber
        case .tool where activeIconWarning:
            color = longRunningToolIconTint
        case .tool, .compacting:
            color = iconSystem ? nil : blue
        default:
            color = iconSystem ? nil : codexGreen
        }

        if iconStyle == .pet, let pet = effectivePet(), let petImage = petImage(for: pet) {
            return petIcon(source: petImage, state: state, frame: frame)
        }
        if state == .permission {
            return dotIcon(color: color)
        }
        if iconSystem, let installedCodexTemplateIcon {
            return appIcon(source: installedCodexTemplateIcon, state: state, frame: frame, isTemplate: true)
        }
        if let installedCodexTemplateIcon, let color {
            return tintedAppIcon(source: installedCodexTemplateIcon, color: color, state: state, frame: frame)
        }
        if let installedCodexIcon {
            return appIcon(source: installedCodexIcon, state: state, frame: frame, isTemplate: false)
        }
        return codexIcon(color: color, state: state, frame: frame)
    }

    func dotIcon(color: NSColor?) -> NSImage {
        let size: CGFloat = 18
        let dot: CGFloat = 9
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            (color ?? NSColor.labelColor).setFill()
            NSBezierPath(ovalIn: NSRect(x: (size - dot) / 2, y: (size - dot) / 2, width: dot, height: dot)).fill()
            return true
        }
        image.isTemplate = color == nil
        return image
    }

    func loadInstalledCodexIcon() -> NSImage? {
        let candidates = [
            "/Applications/Codex.app/Contents/Resources/icon-codex-dark-color.png",
            "/Applications/Codex.app/Contents/Resources/icon.png",
            "/Applications/Codex.app/Contents/Resources/app.icns",
            "/Applications/Codex.app/Contents/Resources/icon.icns",
            "/Applications/Codex.app/Contents/Resources/electron.icns",
        ]

        for path in candidates where FileManager.default.fileExists(atPath: path) {
            if let image = NSImage(contentsOfFile: path) {
                return image
            }
        }
        return nil
    }

    func loadInstalledCodexTemplateIcon() -> NSImage? {
        let candidates = [
            "/Applications/Codex.app/Contents/Resources/codexTemplate@2x.png",
            "/Applications/Codex.app/Contents/Resources/codexTemplate.png",
        ]

        for path in candidates where FileManager.default.fileExists(atPath: path) {
            if let image = NSImage(contentsOfFile: path) {
                image.isTemplate = true
                return image
            }
        }
        return nil
    }

    func appIcon(source: NSImage, state: State, frame: Int, isTemplate: Bool) -> NSImage {
        let size: CGFloat = 18
        let active = state == .thinking || state == .tool || state == .compacting
        let pulseScale = active ? 0.94 + 0.06 * pulse(frame: frame, index: 0) : 1
        let drawSize = size * pulseScale
        let origin = (size - drawSize) / 2
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            source.draw(
                in: NSRect(x: origin, y: origin, width: drawSize, height: drawSize),
                from: .zero,
                operation: .sourceOver,
                fraction: active ? 0.92 : 1
            )
            return true
        }
        image.isTemplate = isTemplate
        return image
    }

    func tintedAppIcon(source: NSImage, color: NSColor, state: State, frame: Int) -> NSImage {
        let size: CGFloat = 18
        let active = state == .thinking || state == .tool || state == .compacting
        let pulseScale = active ? 0.94 + 0.06 * pulse(frame: frame, index: 0) : 1
        let drawSize = size * pulseScale
        let origin = (size - drawSize) / 2
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let rect = NSRect(x: origin, y: origin, width: drawSize, height: drawSize)
            source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            color.withAlphaComponent(active ? 0.92 : 1).setFill()
            rect.fill(using: .sourceAtop)
            return true
        }
        image.isTemplate = false
        return image
    }

    func loadPets() -> [PetInfo] {
        let petsDir = (NSHomeDirectory() as NSString).appendingPathComponent(".codex/pets")
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: petsDir) else { return [] }

        var byId: [String: PetInfo] = [:]
        for entry in entries.sorted() {
            let dir = (petsDir as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue else { continue }
            let manifestPath = (dir as NSString).appendingPathComponent("pet.json")
            guard let data = FileManager.default.contents(atPath: manifestPath),
                  let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = manifest["id"] as? String,
                  let displayName = manifest["displayName"] as? String else { continue }
            let spritesheetName = manifest["spritesheetPath"] as? String ?? "spritesheet.webp"
            let spritesheetPath = (dir as NSString).appendingPathComponent(spritesheetName)
            guard FileManager.default.fileExists(atPath: spritesheetPath) else { continue }
            byId[id] = PetInfo(id: id, displayName: displayName, spritesheetPath: spritesheetPath)
        }

        return byId.values.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func effectivePet() -> PetInfo? {
        if let selected = pets.first(where: { $0.id == selectedPetId }) {
            return selected
        }
        return pets.first
    }

    func petImage(for pet: PetInfo) -> NSImage? {
        if let cached = petImageCache[pet.id] {
            return cached
        }
        guard let image = NSImage(contentsOfFile: pet.spritesheetPath) else { return nil }
        petImageCache[pet.id] = image
        return image
    }

    func petIcon(source: NSImage, state: State, frame: Int) -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let animation = self.petAnimation(for: state)
            let cellWidth: CGFloat = 192
            let cellHeight: CGFloat = 208
            let column = frame % animation.frames
            let row = animation.row
            let sourceY = max(0, source.size.height - CGFloat(row + 1) * cellHeight)
            let sourceRect = NSRect(
                x: CGFloat(column) * cellWidth,
                y: sourceY,
                width: cellWidth,
                height: cellHeight
            )
            let drawHeight: CGFloat = self.shouldAnimate(state: state) ? 18 : 17
            let drawWidth = drawHeight * (cellWidth / cellHeight)
            let originX = (size - drawWidth) / 2
            let originY = (size - drawHeight) / 2
            source.draw(
                in: NSRect(x: originX, y: originY, width: drawWidth, height: drawHeight),
                from: sourceRect,
                operation: .sourceOver,
                fraction: 1
            )
            if state == .permission {
                self.amber.setFill()
                NSBezierPath(ovalIn: NSRect(x: size - 5.5, y: size - 5.5, width: 5, height: 5)).fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    func shouldAnimate(state: State) -> Bool {
        switch state {
        case .thinking, .tool, .compacting:
            return true
        case .permission, .waiting:
            return iconStyle == .pet
        case .idle, .done:
            return false
        }
    }

    func petAnimation(for state: State) -> PetAnimation {
        switch state {
        case .thinking:
            return PetAnimation(row: 8, frames: 6)
        case .tool, .compacting:
            return PetAnimation(row: 7, frames: 6)
        case .permission, .waiting:
            return PetAnimation(row: 6, frames: 6)
        case .idle, .done:
            return PetAnimation(row: 0, frames: 6)
        }
    }

    func codexIcon(color: NSColor?, state: State, frame: Int) -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let drawColor = color ?? NSColor.labelColor
            let active = state == .thinking || state == .tool || state == .compacting
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let phase = CGFloat(active ? frame % 12 : 0)
            let rotation = active ? phase * (.pi / 18) : 0
            let core = NSBezierPath()
            let radius: CGFloat = 2.05
            core.appendOval(in: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            drawColor.withAlphaComponent(active ? 0.55 : 0.72).setFill()
            core.fill()

            for index in 0..<6 {
                let angle = CGFloat(index) * (.pi / 3) + rotation
                let alpha = active ? (0.42 + 0.58 * self.pulse(frame: frame, index: index)) : 0.92
                let arm = self.knotArm(center: center, angle: angle)
                drawColor.withAlphaComponent(alpha).setStroke()
                arm.lineCapStyle = .round
                arm.lineJoinStyle = .round
                arm.lineWidth = 2.35
                arm.stroke()
            }
            return true
        }
        image.isTemplate = color == nil
        return image
    }

    func pulse(frame: Int, index: Int) -> CGFloat {
        let offset = CGFloat((frame + index * 2) % 12) / 11
        return 0.5 - 0.5 * cos(offset * 2 * .pi)
    }

    func knotArm(center: NSPoint, angle: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let inner: CGFloat = 2.55
        let outer: CGFloat = 7.25
        let tangent: CGFloat = 2.8
        let start = point(center: center, angle: angle - 0.52, radius: inner)
        let c1 = point(center: center, angle: angle - 0.22, radius: tangent + 2.6)
        let c2 = point(center: center, angle: angle + 0.20, radius: outer)
        let end = point(center: center, angle: angle + 0.52, radius: outer - 0.55)
        path.move(to: start)
        path.curve(to: end, controlPoint1: c1, controlPoint2: c2)
        return path
    }

    func point(center: NSPoint, angle: CGFloat, radius: CGFloat) -> NSPoint {
        NSPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = StatusController()
app.run()
