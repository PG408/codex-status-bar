import Foundation

struct SessionStateRuleInput {
    let state: String
    let startedAt: Double
    let ts: Double
    let isDesktop: Bool
    let codexRunning: Bool
    let hasLivePid: Bool
    let interruptedByUser: Bool
    let now: Double
}

enum SessionStateRules {
    static let staleAfter: TimeInterval = 15 * 60
    static let longRunningToolAfter: TimeInterval = 3 * 60
    static let completedSessionPruneAfter: TimeInterval = 5 * 60
    static let idleSessionPruneAfter: TimeInterval = 30 * 60
    static let orphanPruneAfter: TimeInterval = 2 * 60 * 60

    static func effectiveState(_ input: SessionStateRuleInput) -> String {
        let state = input.state

        if ["thinking", "tool", "compacting", "permission", "waiting"].contains(state), input.interruptedByUser {
            return "idle"
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

    static func shouldRemoveSession(
        state: String,
        effectiveState: String,
        pid: Int32,
        pidAlive: Bool,
        isDesktop: Bool,
        codexRunning: Bool,
        ts: Double,
        now: Double
    ) -> Bool {
        if isDesktop {
            if !codexRunning {
                return true
            }
            if ts > 0, state == "done", now - ts > completedSessionPruneAfter {
                return true
            }
            if ts > 0, ["idle", "waiting"].contains(effectiveState), now - ts > idleSessionPruneAfter {
                return true
            }
            return false
        }

        if pid > 0, !pidAlive {
            return true
        }
        if pid == 0, ts > 0, now - ts > orphanPruneAfter {
            return true
        }
        return false
    }
}
