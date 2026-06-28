import Cocoa

final class StatusController: NSObject, NSMenuDelegate {
    enum State: String {
        case idle
        case done
        case thinking
        case tool
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
    let defaultStateDir = (NSHomeDirectory() as NSString).appendingPathComponent(".codex/statusbar/state.d")
    let defaultLegacyStatePath = (NSHomeDirectory() as NSString).appendingPathComponent(".codex/statusbar/state.json")
    let pollInterval: TimeInterval = 0.4
    let staleAfter: TimeInterval = 15 * 60
    let quietThinkingAfter: TimeInterval = 60

    var stateDir: String {
        ProcessInfo.processInfo.environment["CODEX_STATUSBAR_STATE_DIR"] ?? defaultStateDir
    }

    var legacyStatePath: String {
        ProcessInfo.processInfo.environment["CODEX_STATUSBAR_STATE_PATH"] ?? defaultLegacyStatePath
    }

    var pollTimer: Timer?
    var animTimer: Timer?

    struct Session {
        var id: String
        var state: State
        var label: String
        var tool: String
        var project: String
        var sessionId: String
        var turnId: String
        var pid: Int32
        var entrypoint: String
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
            self.project = object["project"] as? String ?? ""
            self.sessionId = object["sessionId"] as? String ?? id
            self.turnId = object["turnId"] as? String ?? ""
            self.pid = Int32(truncatingIfNeeded: (object["pid"] as? NSNumber)?.intValue ?? 0)
            self.entrypoint = object["entrypoint"] as? String ?? ""
            self.started = object["started"] as? Bool ?? false
            self.startedAt = (object["startedAt"] as? NSNumber)?.doubleValue ?? 0
            self.ts = (object["ts"] as? NSNumber)?.doubleValue ?? 0
            self.visibleUntilMs = (object["visibleUntilMs"] as? NSNumber)?.doubleValue ?? 0
            self.effectiveState = self.state
        }
    }

    var sessions: [String: Session] = [:]
    var fileMTimes: [String: Date] = [:]
    var legacyMTime: Date = .distantPast

    var activeLabel = ""
    var activeStartedAt: Double = 0
    var activeState: State = .idle
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

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        render(state: .idle, label: "", startedAt: 0)

        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        tick()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let title = NSMenuItem(title: "Codex Status Bar", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

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

        let revealItem = NSMenuItem(title: "Reveal State Directory", action: #selector(revealStateFile), keyEquivalent: "")
        revealItem.target = self
        menu.addItem(revealItem)

        let resetItem = NSMenuItem(title: "Reset Status", action: #selector(resetStatus), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Codex Status Bar", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
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
        render(state: activeState, label: activeLabel, startedAt: activeStartedAt)
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
        render(state: activeState, label: activeLabel, startedAt: activeStartedAt)
    }

    @objc func selectPet(_ sender: NSMenuItem) {
        guard let petId = sender.representedObject as? String else { return }
        selectedPetId = petId
        iconStyle = .pet
        UserDefaults.standard.set(petId, forKey: "selectedPetId")
        UserDefaults.standard.set(IconStyle.pet.rawValue, forKey: "iconStyle")
        render(state: activeState, label: activeLabel, startedAt: activeStartedAt)
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
        evaluate()
    }

    func stateFileNames() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: stateDir)) ?? []).filter { $0.hasSuffix(".json") }
    }

    func reloadSessions() {
        let files = stateFileNames()
        if files.isEmpty {
            loadLegacyStateIfNeeded()
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
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let id = (file as NSString).deletingPathExtension
            sessions[id] = Session(json: object, id: id)
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
        let now = Date().timeIntervalSince1970
        for id in Array(sessions.keys) {
            guard var session = sessions[id] else { continue }
            session.effectiveState = effectiveState(for: session, now: now)
            sessions[id] = session
        }

        guard let lead = sessions.values.max(by: { left, right in
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
        let startedAt = state == .thinking || state == .tool ? lead.startedAt : 0

        switch state {
        case .thinking:
            logRender(state: .thinking, label: label, startedAt: startedAt)
            render(state: .thinking, label: label.isEmpty ? "Thinking..." : label, startedAt: startedAt)
        case .tool:
            logRender(state: .tool, label: label, startedAt: startedAt)
            render(state: .tool, label: label.isEmpty ? "Working..." : label, startedAt: startedAt)
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

    func effectiveState(for session: Session, now: Double) -> State {
        var state = session.state
        if [.thinking, .tool, .permission, .waiting].contains(state), session.ts > 0 {
            let age = now - session.ts
            if age > staleAfter {
                return .idle
            }
        }

        if state == .tool, session.visibleUntilMs > 0, now * 1000 > session.visibleUntilMs {
            state = .thinking
        }

        if state == .thinking, session.ts > 0 {
            let quietAge = now - session.ts
            if quietAge > quietThinkingAfter {
                return .idle
            }
        }

        return state
    }

    func priority(of state: State) -> Int {
        switch state {
        case .permission:
            return 2
        case .thinking, .tool:
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

    func render(state: State, label: String, startedAt: Double) {
        playSoundIfNeeded(for: state)
        activeState = state
        activeLabel = label
        activeStartedAt = startedAt

        let shouldAnimate = shouldAnimate(state: state)
        if shouldAnimate {
            if animTimer == nil {
                let timer = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in
                    self?.animate()
                }
                RunLoop.main.add(timer, forMode: .common)
                animTimer = timer
            }
        } else {
            animTimer?.invalidate()
            animTimer = nil
            frameIndex = 0
            statusItem.button?.image = icon(for: state, frame: frameIndex)
        }

        if statusItem.button?.image == nil {
            statusItem.button?.image = icon(for: state, frame: frameIndex)
        }
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
        case .idle, .thinking, .tool, .waiting:
            return
        }
    }

    func playSystemSound(named name: String) {
        NSSound(named: NSSound.Name(name))?.play()
    }

    func animate() {
        frameIndex = (frameIndex + 1) % 12
        statusItem.button?.image = icon(for: activeState, frame: frameIndex)
        applyTitle()
    }

    func applyTitle() {
        guard let button = statusItem.button else { return }
        var text = activeLabel

        if !showStatusText {
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
            button.imagePosition = .imageOnly
            button.attributedTitle = NSAttributedString(string: "")
            return
        }

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
        case .tool:
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
        let active = state == .thinking || state == .tool
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
        let active = state == .thinking || state == .tool
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
        case .thinking, .tool:
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
        case .tool:
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
            let active = state == .thinking || state == .tool
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
