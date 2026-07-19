import Foundation

struct SessionStateRuleInput {
    let state: String
    let startedAt: Double
    let ts: Double
    let isDesktop: Bool
    let codexRunning: Bool
    let hasLivePid: Bool
    let transcriptTerminalState: TranscriptTerminalState
    let now: Double
}

enum SessionStateRules {
    static let staleAfter: TimeInterval = 15 * 60
    static let longRunningToolAfter: TimeInterval = 3 * 60
    static let sessionRetentionAfter: TimeInterval = 7 * 24 * 60 * 60

    static func shouldRestoreMainPresentation(
        activity: String,
        activeSubagentKey: String,
        transcriptSubagentKey: String,
        subagentTerminalState: TranscriptTerminalState
    ) -> Bool {
        guard activity == "subagent",
              !activeSubagentKey.isEmpty,
              activeSubagentKey == transcriptSubagentKey else { return false }
        return subagentTerminalState == .completed || subagentTerminalState == .interrupted
    }

    static func effectiveState(_ input: SessionStateRuleInput) -> String {
        let state = input.state

        if ["thinking", "tool", "compacting", "permission", "waiting"].contains(state) {
            switch input.transcriptTerminalState {
            case .completed:
                return "done"
            case .interrupted:
                return "idle"
            case .none:
                break
            }
        }

        if input.isDesktop, !input.codexRunning {
            return "idle"
        }
        if input.isDesktop, ["thinking", "tool", "compacting"].contains(state), input.ts > 0 {
            let age = input.now - input.ts
            if age > staleAfter {
                return "waiting"
            }
        }
        if ["thinking", "tool", "compacting", "permission", "waiting"].contains(state),
           !input.isDesktop,
           !input.hasLivePid,
           input.ts > 0 {
            let age = input.now - input.ts
            if age > staleAfter {
                return "idle"
            }
        }

        return state
    }

    static func isLongRunningTool(state: String, ts: Double, now: Double) -> Bool {
        state == "tool" && ts > 0 && now - ts > longRunningToolAfter
    }

    static func isDesktopHostCommand(_ command: String) -> Bool {
        command.contains("/Applications/Codex.app/") ||
            command.contains("/Applications/ChatGPT.app/") ||
            command.contains("Codex.app/Contents/Resources/codex") ||
            command.contains("ChatGPT.app/Contents/Resources/codex")
    }

    static func shouldRemoveSession(
        ts: Double,
        now: Double,
        retentionAfter: TimeInterval = sessionRetentionAfter
    ) -> Bool {
        retentionAfter > 0 && ts > 0 && now - ts > retentionAfter
    }

    static func shouldHideSession(
        effectiveState: String,
        ts: Double,
        now: Double,
        visibilityAfter: TimeInterval
    ) -> Bool {
        let isResting = ["idle", "done", "waiting"].contains(effectiveState)
        return visibilityAfter > 0 && isResting && now - ts > visibilityAfter
    }
}
