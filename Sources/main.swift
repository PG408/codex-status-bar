import Cocoa
import Darwin

private enum LegacyPreferenceMigrator {
    private static let legacyDomainNames = [
        "io.github.pg408.codexstatusbar",
        "com.local.codexstatusbar",
    ]

    static func migrateIfNeeded(defaults: UserDefaults = .standard,
                                currentDomainName: String? = Bundle.main.bundleIdentifier) {
        guard let currentDomainName else { return }
        let currentDomain = defaults.persistentDomain(forName: currentDomainName) ?? [:]
        guard PreferenceMigrationRules.migrationRequired(currentDomain: currentDomain) else {
            return
        }
        let legacyDomains = legacyDomainNames
            .filter { $0 != currentDomainName }
            .compactMap { defaults.persistentDomain(forName: $0) }
        let plan = PreferenceMigrationRules.makePlan(
            legacyDomains: legacyDomains,
            currentDomain: currentDomain
        )
        guard plan.shouldWriteMarker else { return }

        for key in plan.valuesToWrite.keys.sorted() {
            defaults.set(plan.valuesToWrite[key], forKey: key)
        }
        defaults.set(PreferenceMigrationRules.migrationVersion,
                     forKey: PreferenceMigrationRules.markerKey)
    }
}

final class SessionRowView: NSView {
    let id: String
    var onClick: (() -> Void)?
    private let nameField = NSTextField(labelWithString: "")
    private let timerField = NSTextField(labelWithString: "")
    private let badgeView = NSImageView()
    private let highlightView = NSVisualEffectView()
    private let rowH: CGFloat = 24
    private let timerW: CGFloat = 74
    private let maxNameW: CGFloat = 230
    private let nameX: CGFloat = 30
    private let textH: CGFloat = 16
    private var textY: CGFloat { (rowH - textH) / 2 }
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
        nameField.frame = NSRect(x: nameX, y: textY, width: 150, height: textH)
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
                                      height: textH)
            nameField.frame.size.width = min(maxNameW, max(70, timerField.frame.minX - nameField.frame.minX - 8))
        } else {
            timerField.isHidden = true
            nameField.frame.size.width = min(maxNameW, max(120, badgeLeft - nameField.frame.minX - 8))
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
    private static let mainStatusItemAutosaveName = "main-status-item-v1"

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
    let maintenanceInterval: TimeInterval = 5
    let autoExitDelay: TimeInterval = 20
    let defaultThreadName = "Unknown"
    let sideChatRestingMenuHideAfter: TimeInterval = 5 * 60
    let statusIconWidth: CGFloat = 18
    let statusIconLeftInset: CGFloat = 1
    let statusIconTextGap: CGFloat = 2
    let statusIconTimerGap: CGFloat = 2
    let statusTextTimerGap: CGFloat = 6
    let statusTimerSafetyPadding: CGFloat = 1
    let statusVerticalInset: CGFloat = 2

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
        var sessionKind: String
        var threadName: String
        var project: String
        var sessionId: String
        var turnId: String
        var pid: Int32
        var entrypoint: String
        var entrypointSource: String
        var termProgram: String
        var focusTarget: FocusTarget
        var activity: String
        var activeSubagentKey: String
        var transcript: String
        var subagentTranscript: String
        var subagentTranscriptKey: String
        var mainState: State
        var mainLabel: String
        var mainTool: String
        var mainStartedAt: Double
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
            self.sessionKind = object["sessionKind"] as? String ?? ""
            self.threadName = object["threadName"] as? String ?? ""
            self.project = object["project"] as? String ?? ""
            self.sessionId = object["sessionId"] as? String ?? id
            self.turnId = object["turnId"] as? String ?? ""
            self.pid = Int32(truncatingIfNeeded: (object["pid"] as? NSNumber)?.intValue ?? 0)
            self.entrypoint = object["entrypoint"] as? String ?? ""
            self.entrypointSource = object["entrypointSource"] as? String ?? ""
            self.termProgram = object["termProgram"] as? String ?? object["term_program"] as? String ?? ""
            self.focusTarget = FocusTarget(object: object["focusTarget"] as? [String: Any])
            self.activity = object["activity"] as? String ?? ""
            self.activeSubagentKey = object["activeSubagentKey"] as? String ?? ""
            self.transcript = object["transcript"] as? String ?? object["transcript_path"] as? String ?? ""
            self.subagentTranscript = object["subagentTranscript"] as? String ?? ""
            self.subagentTranscriptKey = object["subagentTranscriptKey"] as? String ?? ""
            let statusFacts = object["statusFacts"] as? [String: Any]
            let mainFact = statusFacts?["main"] as? [String: Any]
            self.mainState = State(rawValue: mainFact?["state"] as? String ?? self.state.rawValue) ?? self.state
            self.mainLabel = mainFact?["label"] as? String ?? self.label
            self.mainTool = mainFact?["tool"] as? String ?? self.tool
            self.mainStartedAt = (mainFact?["startedAt"] as? NSNumber)?.doubleValue ?? 0
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
    var codexDesktopProcessCache = TimedBooleanCache()
    var desktopSessionProcessCaches: [Int32: TimedBooleanCache] = [:]
    var lastMaintenanceTickAt: TimeInterval?
    var lastObservedActiveElapsedSecond: Int?
    var lastObservedMenuSecond: Int?
    var menuIsOpen = false
    var sessionMenuItems: [(item: NSMenuItem, id: String)] = []

    var hideIdleAfter: TimeInterval {
        let stored = UserDefaults.standard.object(forKey: "hideIdleAfter") as? Double ?? 1800
        guard stored > 0 else { return SessionStateRules.sessionRetentionAfter }
        return min(stored, SessionStateRules.sessionRetentionAfter)
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
    var iconStyle: IconStyle = .codex
    var selectedPetId = ""
    lazy var pets: [PetInfo] = loadPets()
    var petImageCache: [String: NSImage] = [:]
    var lastSoundState: State = .idle
    let notificationObservationStartedAt = Date().timeIntervalSince1970
    lazy var bundledCodexTemplateIcon: NSImage? = loadBundledCodexTemplateIcon()
    let statusBitmapRenderer = StatusItemBitmapRenderer()

    let codexGreen = NSColor(srgbRed: 0.08, green: 0.72, blue: 0.48, alpha: 1)
    let codexWhite = NSColor.white
    let lightBlue = NSColor(srgbRed: 0.38, green: 0.68, blue: 1.0, alpha: 1)
    let yellow = NSColor(srgbRed: 1.0, green: 0.78, blue: 0.18, alpha: 1)
    let red = NSColor(srgbRed: 1.0, green: 0.23, blue: 0.20, alpha: 1)
    let amber = NSColor(srgbRed: 0.95, green: 0.70, blue: 0.16, alpha: 1)
    var longRunningToolIconTint: NSColor { amber }

    override init() {
        super.init()

        statusItem.autosaveName = Self.mainStatusItemAutosaveName
        LegacyPreferenceMigrator.migrateIfNeeded()

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
        scheduleInitialStatusAppearanceRefresh()
        scheduleStartupHookRepair()
    }

    func scheduleInitialStatusAppearanceRefresh() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.applyTitle()
        }
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
        _ = reloadSessions()
        refreshThreadMetadata()
        applyArchivedThreadOverlay()
        let codexRunning = codexDesktopProcessExists()
        refreshEffectiveSessionStates(codexRunning: codexRunning)

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
        for (title, seconds) in [
            ("5 minutes", 300.0),
            ("15 minutes", 900.0),
            ("30 minutes", 1800.0),
            ("1 hour", 3600.0),
            ("12 hours", 12 * 3600.0),
            ("24 hours", 24 * 3600.0),
            ("7 days", SessionStateRules.sessionRetentionAfter),
        ] {
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

        let versionItem = NSMenuItem(title: "Version \(appVersion)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

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

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    func tick() {
        let now = Date().timeIntervalSince1970
        let sessionsChanged = reloadSessions()
        let activeElapsedSecond = showTimer ? currentElapsedSeconds() : nil
        let activeTimerSecondChanged = PollingRules.secondChanged(
            current: activeElapsedSecond,
            previous: lastObservedActiveElapsedSecond
        )
        lastObservedActiveElapsedSecond = activeElapsedSecond

        let menuSecond = menuIsOpen ? Int(now) : nil
        let menuTimerSecondChanged = PollingRules.secondChanged(
            current: menuSecond,
            previous: lastObservedMenuSecond
        )
        lastObservedMenuSecond = menuSecond

        let maintenanceDue = PollingRules.maintenanceIsDue(
            now: now,
            previous: lastMaintenanceTickAt,
            interval: maintenanceInterval
        )
        if maintenanceDue {
            lastMaintenanceTickAt = now
        }

        let decision = PollingRules.decision(
            sessionsChanged: sessionsChanged,
            activeTimerSecondChanged: activeTimerSecondChanged,
            menuTimerSecondChanged: menuTimerSecondChanged,
            maintenanceDue: maintenanceDue,
            menuIsOpen: menuIsOpen
        )
        guard decision.shouldEvaluate || decision.shouldRefreshMetadata ||
                decision.shouldRefreshMenu || decision.shouldRunMaintenance else {
            return
        }

        if decision.shouldRefreshMetadata {
            refreshThreadMetadata()
            applyArchivedThreadOverlay()
        }

        let codexRunning = codexDesktopProcessExists(now: now)
        if decision.shouldEvaluate {
            evaluate(codexRunning: codexRunning)
        }
        if decision.shouldRunMaintenance {
            evaluateAutoExit(codexRunning: codexRunning)
        }
        if decision.shouldRefreshMenu {
            refreshOpenMenuRows(codexRunning: codexRunning)
        }
    }

    func stateFileNames() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: stateDir)) ?? []).filter { $0.hasSuffix(".json") }
    }

    @discardableResult
    func reloadSessions() -> Bool {
        let previousNotificationSnapshots = notificationSnapshots()
        let files = stateFileNames()
        if files.isEmpty {
            let changed = loadLegacyStateIfNeeded()
            let hadMetadata = !threadMetadata.isEmpty
            threadMetadata.removeAll()
            playCompletionSoundIfNeeded(previous: previousNotificationSnapshots)
            return changed || hadMetadata
        }

        var changed = false
        if sessions.keys.contains("legacy-state") {
            sessions["legacy-state"] = nil
            legacyMTime = .distantPast
            changed = true
        }

        let present = Set(files)
        for key in Array(fileMTimes.keys) where !present.contains(key) {
            fileMTimes[key] = nil
            sessions[(key as NSString).deletingPathExtension] = nil
            changed = true
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
                changed = true
                continue
            }
            let id = (file as NSString).deletingPathExtension
            sessions[id] = Session(json: object, id: id)
            changed = true
        }
        playCompletionSoundIfNeeded(previous: previousNotificationSnapshots)
        return changed
    }

    func notificationSnapshots() -> [String: SessionNotificationSnapshot] {
        Dictionary(uniqueKeysWithValues: sessions.map { sessionId, session in
            (sessionId, SessionNotificationSnapshot(
                state: session.mainState.rawValue,
                timestamp: session.ts
            ))
        })
    }

    func playCompletionSoundIfNeeded(previous: [String: SessionNotificationSnapshot]) {
        guard playNotificationSounds else { return }
        guard NotificationSoundRules.shouldPlayCompletion(
            previous: previous,
            current: notificationSnapshots(),
            observationStartedAt: notificationObservationStartedAt
        ) else { return }
        playSystemSound(named: "Glass")
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

    @discardableResult
    func loadLegacyStateIfNeeded() -> Bool {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: legacyStatePath),
              let mtime = attrs[.modificationDate] as? Date else {
            let changed = !sessions.isEmpty || !fileMTimes.isEmpty || legacyMTime != .distantPast
            sessions.removeAll()
            fileMTimes.removeAll()
            legacyMTime = .distantPast
            return changed
        }

        guard mtime != legacyMTime else { return false }
        legacyMTime = mtime
        fileMTimes.removeAll()
        sessions.removeAll()
        if let data = fm.contents(atPath: legacyStatePath),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            sessions["legacy-state"] = Session(json: object, id: "legacy-state")
        }
        return true
    }

    func evaluate(codexRunning: Bool) {
        refreshEffectiveSessionStates(codexRunning: codexRunning)
        cleanupDeadSessions()

        let displaySessions = sessions.values.filter { isDisplayableSession($0) }
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
            render(state: .thinking, label: label.isEmpty ? "Thinking" : label, startedAt: startedAt)
        case .tool:
            logRender(state: .tool, label: label, startedAt: startedAt)
            render(state: .tool, label: label.isEmpty ? "Using tool" : label, startedAt: startedAt, iconWarning: iconWarning)
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

    func refreshEffectiveSessionStates(codexRunning: Bool) {
        let now = Date().timeIntervalSince1970
        for id in Array(sessions.keys) {
            guard var session = sessions[id] else { continue }
            let subagentTerminalState = transcriptTerminalState(
                session.subagentTranscript,
                after: session.ts
            )
            let restoreMain = SessionStateRules.shouldRestoreMainPresentation(
                activity: session.activity,
                activeSubagentKey: session.activeSubagentKey,
                transcriptSubagentKey: session.subagentTranscriptKey,
                subagentTerminalState: subagentTerminalState
            )
            if restoreMain {
                session.label = session.mainLabel
                session.tool = session.mainTool
                session.startedAt = session.mainStartedAt
            }
            session.effectiveState = effectiveState(
                for: session,
                state: restoreMain ? session.mainState : session.state,
                now: now,
                codexRunning: codexRunning
            )
            sessions[id] = session
        }
    }

    func cleanupSessionFilesOnStartup() {
        try? FileManager.default.createDirectory(atPath: stateDir, withIntermediateDirectories: true)
        let now = Date().timeIntervalSince1970
        let fm = FileManager.default
        for file in stateFileNames() {
            let fullPath = (stateDir as NSString).appendingPathComponent(file)
            guard let data = fm.contents(atPath: fullPath),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                removeCorruptSessionFile(file)
                continue
            }
            let session = Session(json: object, id: (file as NSString).deletingPathExtension)
            if shouldRemoveSession(session, now: now) {
                removeDeadSession(session.id)
                continue
            }
        }
    }

    func cleanupDeadSessions() {
        let now = Date().timeIntervalSince1970
        for session in sessions.values {
            if shouldRemoveSession(session, now: now) {
                removeDeadSession(session.id)
            }
        }
    }

    func shouldRemoveSession(_ session: Session, now: Double) -> Bool {
        return SessionStateRules.shouldRemoveSession(
            ts: session.ts,
            now: now
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
        let now = Date().timeIntervalSince1970
        let ordered = sessions.values.filter { isDisplayableSession($0) }.sorted { left, right in
            let leftPriority = priority(of: left.effectiveState)
            let rightPriority = priority(of: right.effectiveState)
            return leftPriority == rightPriority ? left.ts > right.ts : leftPriority > rightPriority
        }

        let filtered = ordered.filter { session in
            if isHiddenSideChatMenuSession(session, now: now) {
                return false
            }
            return !SessionStateRules.shouldHideSession(
                effectiveState: session.effectiveState.rawValue,
                ts: session.ts,
                now: now,
                visibilityAfter: hideIdleAfter
            )
        }
        return filtered
    }

    func isDisplayableSession(_ session: Session) -> Bool {
        !isArchivedThread(session) &&
            session.sessionKind != "commit-message"
    }

    func isHiddenSideChatMenuSession(_ session: Session, now: Double) -> Bool {
        isSideChatSession(session) &&
            isRestingMenuState(session) &&
            session.ts > 0 &&
            now - session.ts > sideChatRestingMenuHideAfter
    }

    func isSideChatSession(_ session: Session) -> Bool {
        session.threadName.trimmingCharacters(in: .whitespacesAndNewlines) == "Side Chat"
    }

    func isRestingMenuState(_ session: Session) -> Bool {
        priority(of: session.effectiveState) == 0
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

    func refreshOpenMenuRows(codexRunning: Bool) {
        refreshEffectiveSessionStates(codexRunning: codexRunning)
        for (item, id) in sessionMenuItems {
            guard let session = sessions[id], let row = item.view as? SessionRowView else { continue }
            configureSessionRow(row, session)
        }
    }

    func configureSessionRow(_ row: SessionRowView, _ session: Session) {
        let tag = surfaceTag(for: session)
        let running = sessionBadgeIsRunning(session)
        row.configure(name: sessionName(for: session),
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
        guard pid > 0 else { return false }
        var cache = desktopSessionProcessCaches[pid] ?? TimedBooleanCache()
        let result = cache.resolve(
            now: Date().timeIntervalSince1970,
            ttl: maintenanceInterval
        ) { [unowned self] in
            let command = self.processCommand(pid: pid)
            return SessionStateRules.isDesktopHostCommand(command)
        }
        desktopSessionProcessCaches[pid] = cache
        return result
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
        process.arguments = [installer, "--app-path", Bundle.main.bundlePath]
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

    func codexDesktopProcessExists(now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        var cache = codexDesktopProcessCache
        let result = cache.resolve(now: now, ttl: maintenanceInterval) { [unowned self] in
            self.detectCodexDesktopProcess()
        }
        codexDesktopProcessCache = cache
        return result
    }

    func detectCodexDesktopProcess() -> Bool {
        NSWorkspace.shared.runningApplications.contains { application in
            if application.bundleIdentifier == "com.openai.codex" {
                return true
            }
            if application.bundleURL?.path.contains("/Codex.app") == true {
                return true
            }
            if application.bundleURL?.path.contains("/ChatGPT.app") == true {
                return true
            }
            return application.localizedName == "Codex" || application.localizedName == "ChatGPT"
        }
    }

    func evaluateAutoExit(codexRunning: Bool) {
        guard ProcessInfo.processInfo.environment["CODEX_STATUSBAR_DISABLE_AUTO_EXIT"] != "1" else { return }
        if codexRunning || hasLiveSession() {
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
        effectiveState(for: session, state: session.state, now: now, codexRunning: codexRunning)
    }

    func effectiveState(
        for session: Session,
        state: State,
        now: Double,
        codexRunning: Bool
    ) -> State {
        let isDesktop = isDesktopSession(session)
        let hasLivePid = !isDesktop && session.pid > 0 && pidAlive(session.pid)
        let state = SessionStateRules.effectiveState(SessionStateRuleInput(
            state: state.rawValue,
            startedAt: session.startedAt,
            ts: session.ts,
            isDesktop: isDesktop,
            codexRunning: codexRunning,
            hasLivePid: hasLivePid,
            transcriptTerminalState: transcriptTerminalState(
                session.transcript,
                after: session.ts
            ),
            now: now
        ))
        return State(rawValue: state) ?? session.state
    }

    func transcriptTerminalState(_ path: String, after stateTimestamp: Double) -> TranscriptTerminalState {
        guard !path.isEmpty, let tail = transcriptTail(ofFileAt: path) else { return .none }
        return TranscriptStateRules.terminalState(in: tail, after: stateTimestamp)
    }

    func transcriptTail(ofFileAt path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let chunk: UInt64 = 64 * 1024
        try? handle.seek(toOffset: size > chunk ? size - chunk : 0)
        guard let data = try? handle.readToEnd() else { return nil }
        return String(data: data, encoding: .utf8)
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
        let label: String
        switch session.effectiveState {
        case .thinking:
            label = session.label.isEmpty ? "Thinking" : session.label
        case .tool:
            label = session.label.isEmpty ? "Using tool" : session.label
        case .compacting:
            label = session.label.isEmpty ? "Compacting" : session.label
        case .permission:
            label = session.label.isEmpty ? "Awaiting permission" : session.label
        case .waiting:
            label = session.label.isEmpty ? "Waiting" : session.label
        case .idle, .done:
            label = ""
        }
        return normalizedStatusLabel(label)
    }

    func normalizedStatusLabel(_ label: String) -> String {
        switch label {
        case "Running command":
            return "Running cmd"
        case "Browsing web":
            return "Browsing"
        case "Searching web":
            return "Web search"
        case "Subagent running":
            return "Subagent"
        case "Subagent awaiting permission":
            return "Subagent permission"
        default:
            return label
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
        applyTitle()
    }

    func playSoundIfNeeded(for state: State) {
        guard state != lastSoundState else { return }
        lastSoundState = state
        guard playNotificationSounds else { return }

        switch state {
        case .permission:
            playSystemSound(named: "Ping")
        case .idle, .done, .thinking, .tool, .compacting, .waiting:
            return
        }
    }

    func playSystemSound(named name: String) {
        NSSound(named: NSSound.Name(name))?.play()
    }

    func applyTitle() {
        guard let button = statusItem.button else { return }
        guard activeState != .idle && activeState != .done else {
            applyIconOnlyStatus(to: button)
            return
        }

        let timer = currentStatusTimer()
        if !showStatusText && !showTimer {
            applyIconOnlyStatus(to: button)
            return
        }

        let label = showStatusText ? activeLabel : ""
        let displayedTimer = showTimer ? timer : ""
        let layout = statusTitleLayout(label: label, timer: displayedTimer)
        let height = max(button.bounds.height, NSStatusItem.squareLength)
        let appearanceName = button.effectiveAppearance.name.rawValue
        let content = StatusItemBitmapContent(
            size: NSSize(width: layout.itemWidth, height: height),
            icon: icon(for: activeState, frame: frameIndex),
            iconRect: NSRect(x: statusIconLeftInset,
                             y: (height - statusIconWidth) / 2,
                             width: statusIconWidth,
                             height: statusIconWidth),
            label: label,
            labelRect: NSRect(x: layout.textX,
                              y: statusVerticalInset,
                              width: layout.textWidth,
                              height: height - statusVerticalInset * 2),
            timer: displayedTimer,
            timerRect: NSRect(x: layout.timerX,
                              y: statusVerticalInset,
                              width: layout.timerWidth,
                              height: height - statusVerticalInset * 2),
            font: statusTitleFont(),
            textColor: .labelColor
        )
        let cacheKey = [
            activeState.rawValue,
            label,
            displayedTimer,
            String(Int(layout.itemWidth)),
            String(Int(height)),
            iconStyle.rawValue,
            selectedPetId,
            activeIconWarning ? "warning" : "normal",
            appearanceName,
        ].joined(separator: "|")

        statusItem.length = layout.itemWidth
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.effectiveAppearance.performAsCurrentDrawingAppearance {
            button.image = statusBitmapRenderer.image(cacheKey: cacheKey, content: content)
        }
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        applyAccessibility(to: button, label: label, timer: displayedTimer)
    }

    func applyIconOnlyStatus(to button: NSStatusBarButton) {
        statusItem.length = NSStatusItem.squareLength
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.image = icon(for: activeState, frame: frameIndex)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        applyAccessibility(to: button, label: "", timer: "")
    }

    func applyAccessibility(to button: NSStatusBarButton, label: String, timer: String) {
        let stateLabel = label.isEmpty ? activeState.rawValue.capitalized : label
        let value = timer.isEmpty ? stateLabel : "\(stateLabel), \(timer)"
        button.setAccessibilityLabel("Codex Status Bar")
        button.setAccessibilityValue(value)
    }

    struct StatusTitleLayout {
        let itemWidth: CGFloat
        let textX: CGFloat
        let textWidth: CGFloat
        let timerX: CGFloat
        let timerWidth: CGFloat
    }

    func statusTitleLayout(label: String, timer: String) -> StatusTitleLayout {
        let hasText = !label.isEmpty
        let hasTimer = !timer.isEmpty
        let iconX = statusIconLeftInset
        let iconRight = iconX + statusIconWidth
        let textX = iconRight + (hasText ? statusIconTextGap : 0)
        let textWidth = hasText ? ceil(measuredTextWidth(label)) : 0
        let timerGap = hasText ? statusTextTimerGap : statusIconTimerGap
        let timerX = hasTimer ? (hasText ? textX + textWidth + timerGap : iconRight + timerGap) : 0
        let timerWidth = hasTimer ? ceil(measuredTextWidth(timer)) + statusTimerSafetyPadding : 0
        let contentRight: CGFloat

        if hasTimer {
            contentRight = timerX + timerWidth
        } else if hasText {
            contentRight = textX + textWidth
        } else {
            contentRight = iconRight
        }

        let itemWidth = contentRight + statusIconLeftInset
        return StatusTitleLayout(itemWidth: itemWidth,
                                 textX: textX,
                                 textWidth: textWidth,
                                 timerX: timerX,
                                 timerWidth: timerWidth)
    }

    func statusTitleFont() -> NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular)
    }

    func statusTitleAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: statusTitleFont(),
        ]
    }

    func measuredTextWidth(_ text: String) -> CGFloat {
        (text as NSString).size(withAttributes: statusTitleAttributes()).width
    }

    func currentStatusTimer() -> String {
        guard let seconds = currentElapsedSeconds() else { return "" }
        return elapsed(seconds)
    }

    func currentElapsedSeconds() -> Int? {
        guard activeStartedAt > 0 else { return nil }
        return max(0, Int(Date().timeIntervalSince1970 - activeStartedAt))
    }

    func icon(for state: State, frame: Int) -> NSImage {
        let color: NSColor
        switch state {
        case .permission:
            color = red
        case .tool where activeIconWarning:
            color = longRunningToolIconTint
        case .tool:
            color = lightBlue
        case .compacting, .waiting:
            color = yellow
        case .thinking:
            color = codexGreen
        case .idle, .done:
            color = codexWhite
        }

        if iconStyle == .pet, let pet = effectivePet(), let petImage = petImage(for: pet) {
            return petIcon(source: petImage, state: state, frame: frame)
        }
        let image: NSImage
        if let templateIcon = bundledCodexTemplateIcon {
            image = tintedAppIcon(source: templateIcon, color: color, state: state, frame: frame)
        } else {
            image = codexIcon(color: color, state: state, frame: frame)
        }
        return state == .permission ? iconWithStatusDot(image, color: red) : image
    }

    func iconWithStatusDot(_ source: NSImage, color: NSColor) -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            source.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                        from: .zero,
                        operation: .sourceOver,
                        fraction: 1)
            let outer = NSRect(x: size - 7, y: size - 7, width: 6, height: 6)
            NSColor.white.withAlphaComponent(0.92).setFill()
            NSBezierPath(ovalIn: outer).fill()
            color.setFill()
            NSBezierPath(ovalIn: outer.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    func loadBundledCodexTemplateIcon() -> NSImage? {
        guard let resourcePath = Bundle.main.resourcePath else { return nil }
        let candidates = [
            (resourcePath as NSString).appendingPathComponent("codexTemplate@2x.png"),
            (resourcePath as NSString).appendingPathComponent("codexTemplate.png"),
        ]

        for path in candidates where FileManager.default.fileExists(atPath: path) {
            if let image = NSImage(contentsOfFile: path) {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                return image
            }
        }
        return nil
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
