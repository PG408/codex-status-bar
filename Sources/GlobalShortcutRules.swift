import Carbon
import Foundation

struct GlobalShortcutDefinition: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String

    var displayText: String {
        var result = ""
        if modifiers & UInt32(controlKey) != 0 { result += "\u{2303}" }
        if modifiers & UInt32(optionKey) != 0 { result += "\u{2325}" }
        if modifiers & UInt32(shiftKey) != 0 { result += "\u{21E7}" }
        if modifiers & UInt32(cmdKey) != 0 { result += "\u{2318}" }
        return result + keyLabel
    }
}

enum CodexVisibilityAction: Equatable {
    case hide
    case activate
    case launch
}

enum GlobalShortcutRules {
    static let defaultShortcut = GlobalShortcutDefinition(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(controlKey | optionKey),
        keyLabel: "Space"
    )

    static func makeShortcut(
        keyCode: UInt32,
        keyLabel: String,
        control: Bool,
        option: Bool,
        shift: Bool,
        command: Bool
    ) -> GlobalShortcutDefinition? {
        let normalizedLabel = keyLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLabel.isEmpty else { return nil }

        var modifiers: UInt32 = 0
        if control { modifiers |= UInt32(controlKey) }
        if option { modifiers |= UInt32(optionKey) }
        if shift { modifiers |= UInt32(shiftKey) }
        if command { modifiers |= UInt32(cmdKey) }
        guard modifiers != 0 else { return nil }

        return GlobalShortcutDefinition(
            keyCode: keyCode,
            modifiers: modifiers,
            keyLabel: normalizedLabel
        )
    }

    static func keyLabel(for keyCode: UInt32, characters: String) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_LeftArrow: return "\u{2190}"
        case kVK_RightArrow: return "\u{2192}"
        case kVK_UpArrow: return "\u{2191}"
        case kVK_DownArrow: return "\u{2193}"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: return characters.uppercased()
        }
    }

    static var recordingCandidates: [GlobalShortcutDefinition] {
        let keys: [(Int, String)] = [
            (kVK_ANSI_A, "A"), (kVK_ANSI_B, "B"), (kVK_ANSI_C, "C"),
            (kVK_ANSI_D, "D"), (kVK_ANSI_E, "E"), (kVK_ANSI_F, "F"),
            (kVK_ANSI_G, "G"), (kVK_ANSI_H, "H"), (kVK_ANSI_I, "I"),
            (kVK_ANSI_J, "J"), (kVK_ANSI_K, "K"), (kVK_ANSI_L, "L"),
            (kVK_ANSI_M, "M"), (kVK_ANSI_N, "N"), (kVK_ANSI_O, "O"),
            (kVK_ANSI_P, "P"), (kVK_ANSI_Q, "Q"), (kVK_ANSI_R, "R"),
            (kVK_ANSI_S, "S"), (kVK_ANSI_T, "T"), (kVK_ANSI_U, "U"),
            (kVK_ANSI_V, "V"), (kVK_ANSI_W, "W"), (kVK_ANSI_X, "X"),
            (kVK_ANSI_Y, "Y"), (kVK_ANSI_Z, "Z"),
            (kVK_ANSI_0, "0"), (kVK_ANSI_1, "1"), (kVK_ANSI_2, "2"),
            (kVK_ANSI_3, "3"), (kVK_ANSI_4, "4"), (kVK_ANSI_5, "5"),
            (kVK_ANSI_6, "6"), (kVK_ANSI_7, "7"), (kVK_ANSI_8, "8"),
            (kVK_ANSI_9, "9"),
            (kVK_Space, "Space"), (kVK_Return, "Return"), (kVK_Tab, "Tab"),
            (kVK_LeftArrow, "\u{2190}"), (kVK_RightArrow, "\u{2192}"),
            (kVK_UpArrow, "\u{2191}"), (kVK_DownArrow, "\u{2193}"),
            (kVK_F1, "F1"), (kVK_F2, "F2"), (kVK_F3, "F3"),
            (kVK_F4, "F4"), (kVK_F5, "F5"), (kVK_F6, "F6"),
            (kVK_F7, "F7"), (kVK_F8, "F8"), (kVK_F9, "F9"),
            (kVK_F10, "F10"), (kVK_F11, "F11"), (kVK_F12, "F12"),
        ]
        let modifierKeys = [controlKey, optionKey, shiftKey, cmdKey]
        let modifierSets = (1 ..< (1 << modifierKeys.count)).map { mask in
            modifierKeys.enumerated().reduce(UInt32(0)) { result, entry in
                mask & (1 << entry.offset) == 0 ? result : result | UInt32(entry.element)
            }
        }
        return modifierSets.flatMap { modifiers in
            keys.map { keyCode, label in
                GlobalShortcutDefinition(
                    keyCode: UInt32(keyCode),
                    modifiers: modifiers,
                    keyLabel: label
                )
            }
        }
    }

    static func visibilityAction(isRunning: Bool, isFrontmost: Bool) -> CodexVisibilityAction {
        guard isRunning else { return .launch }
        return isFrontmost ? .hide : .activate
    }
}

enum GlobalShortcutPreferences {
    private static let enabledKey = "globalShortcutEnabled"
    private static let keyCodeKey = "globalShortcutKeyCode"
    private static let modifiersKey = "globalShortcutModifiers"
    private static let keyLabelKey = "globalShortcutKeyLabel"

    static func load(defaults: UserDefaults = .standard) -> GlobalShortcutDefinition? {
        guard defaults.object(forKey: enabledKey) != nil else {
            return GlobalShortcutRules.defaultShortcut
        }
        guard defaults.bool(forKey: enabledKey) else { return nil }
        guard let keyCode = defaults.object(forKey: keyCodeKey) as? NSNumber,
              let modifiers = defaults.object(forKey: modifiersKey) as? NSNumber,
              let keyLabel = defaults.string(forKey: keyLabelKey),
              !keyLabel.isEmpty else {
            return GlobalShortcutRules.defaultShortcut
        }
        return GlobalShortcutDefinition(
            keyCode: keyCode.uint32Value,
            modifiers: modifiers.uint32Value,
            keyLabel: keyLabel
        )
    }

    static func save(_ shortcut: GlobalShortcutDefinition?, defaults: UserDefaults = .standard) {
        defaults.set(shortcut != nil, forKey: enabledKey)
        guard let shortcut else {
            defaults.removeObject(forKey: keyCodeKey)
            defaults.removeObject(forKey: modifiersKey)
            defaults.removeObject(forKey: keyLabelKey)
            return
        }
        defaults.set(Int(shortcut.keyCode), forKey: keyCodeKey)
        defaults.set(Int(shortcut.modifiers), forKey: modifiersKey)
        defaults.set(shortcut.keyLabel, forKey: keyLabelKey)
    }
}
