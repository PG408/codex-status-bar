#!/usr/bin/env node
const cp = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "codex-status-rules-"));
const verifier = path.join(tmp, "VerifyStateRules.swift");
const binary = path.join(tmp, "verify-state-rules");

function writeVerifier() {
  fs.writeFileSync(verifier, `
import Foundation

func assertEqual(_ actual: String, _ expected: String, _ label: String) {
    if actual != expected {
        fputs("FAIL \\(label): expected \\(expected), got \\(actual)\\n", stderr)
        exit(1)
    }
}

func assertBool(_ actual: Bool, _ expected: Bool, _ label: String) {
    if actual != expected {
        fputs("FAIL \\(label): expected \\(expected), got \\(actual)\\n", stderr)
        exit(1)
    }
}

func assertTerminal(
    _ actual: TranscriptTerminalState,
    _ expected: TranscriptTerminalState,
    _ label: String
) {
    if actual != expected {
        fputs("FAIL \\(label): expected \\(expected), got \\(actual)\\n", stderr)
        exit(1)
    }
}

@main
struct VerifyStateRules {
    static func main() {
        let now = 10_000.0
        let completedTail = [
            #"{"timestamp":"1970-01-01T02:46:30Z","type":"event_msg","payload":{"type":"task_started","started_at":9990}}"#,
            #"{"timestamp":"1970-01-01T02:46:35Z","type":"event_msg","payload":{"type":"task_complete","completed_at":9995}}"#,
        ].joined(separator: "\\n")
        let resumedTail = completedTail + "\\n" +
            #"{"timestamp":"1970-01-01T02:46:38Z","type":"event_msg","payload":{"type":"task_started","started_at":9998}}"#
        let interruptedTail = #"{"timestamp":"1970-01-01T02:46:36Z","type":"event_msg","payload":{"type":"turn_aborted","reason":"interrupted","completed_at":9996}}"#
        let guardianTail = [
            #"{"timestamp":"1970-01-01T02:46:29Z","type":"session_meta","payload":{"session_id":"parent","id":"guardian-child","parent_thread_id":"parent","source":{"subagent":{"other":"guardian"}},"thread_source":"subagent"}}"#,
            #"{"timestamp":"1970-01-01T02:46:35Z","type":"event_msg","payload":{"type":"task_complete","completed_at":9995}}"#,
        ].joined(separator: "\\n")
        assertTerminal(TranscriptStateRules.terminalState(in: completedTail, after: 9_980), .completed, "task_complete after state timestamp ends the turn")
        assertTerminal(TranscriptStateRules.terminalState(in: interruptedTail, after: 9_980), .interrupted, "turn_aborted after state timestamp ends the turn")
        assertTerminal(TranscriptStateRules.terminalState(in: resumedTail, after: 9_980), .none, "newer task_started supersedes an older completion")
        assertTerminal(TranscriptStateRules.terminalState(in: completedTail, after: 9_999), .none, "completion before state timestamp is ignored")
        assertTerminal(TranscriptStateRules.terminalState(in: guardianTail, after: 9_980), .completed, "guardian completion remains available for subagent recovery")
        let active = SessionNotificationSnapshot(state: "thinking", timestamp: 100)
        let done = SessionNotificationSnapshot(state: "done", timestamp: 110)
        assertBool(NotificationSoundRules.shouldPlayCompletion(
            previous: ["session": active],
            current: ["session": done],
            observationStartedAt: 90
        ), true, "main session completion plays a sound")
        assertBool(NotificationSoundRules.shouldPlayCompletion(
            previous: ["session": active],
            current: [:],
            observationStartedAt: 90
        ), false, "leader disappearance does not play a completion sound")
        assertBool(NotificationSoundRules.shouldPlayCompletion(
            previous: [:],
            current: ["session": SessionNotificationSnapshot(state: "done", timestamp: 80)],
            observationStartedAt: 90
        ), false, "retained completion does not play on startup")
        assertBool(NotificationSoundRules.shouldPlayCompletion(
            previous: [:],
            current: ["session": done],
            observationStartedAt: 105
        ), true, "new fast completion after startup plays a sound")
        assertBool(SessionVisibilityRules.shouldSuppress(
            transcript: "",
            isInSessionIndex: false
        ), true, "session without transcript or index entry is suppressed")
        assertBool(SessionVisibilityRules.shouldSuppress(
            transcript: " /tmp/session.jsonl ",
            isInSessionIndex: false
        ), false, "transcript keeps a session visible")
        assertBool(SessionVisibilityRules.shouldSuppress(
            transcript: "",
            isInSessionIndex: true
        ), false, "session index entry keeps a session visible")
        assertBool(SessionVisibilityRules.shouldSuppress(
            transcript: "/tmp/session.jsonl",
            isInSessionIndex: true
        ), false, "either persistence signal is sufficient")
        let indexedIds = SessionVisibilityRules.indexedSessionIds(from: [
            #"{"id":"indexed","thread_name":"Visible"}"#,
            #"{"id":"indexed","thread_name":"Renamed"}"#,
            #"{"id":"second"}"#,
            "{bad json",
        ].joined(separator: "\\n"))
        assertBool(indexedIds == Set(["indexed", "second"]), true, "session index parser returns valid unique ids")
        assertBool(SessionStateRules.shouldRestoreMainPresentation(
            activity: "subagent",
            activeSubagentKey: "guardian-child",
            transcriptSubagentKey: "guardian-child",
            subagentTerminalState: .completed
        ), true, "completed guardian restores the main presentation")
        assertBool(SessionStateRules.shouldRestoreMainPresentation(
            activity: "",
            activeSubagentKey: "",
            transcriptSubagentKey: "guardian-child",
            subagentTerminalState: .completed
        ), false, "main completion does not use subagent recovery")
        assertBool(SessionStateRules.shouldRestoreMainPresentation(
            activity: "subagent",
            activeSubagentKey: "ordinary-agent",
            transcriptSubagentKey: "guardian-child",
            subagentTerminalState: .completed
        ), false, "completed guardian does not hide another active subagent")

        assertBool(SessionStateRules.isDesktopHostCommand(
            "/Applications/ChatGPT.app/Contents/Resources/codex -c features.code_mode_host=true app-server"
        ), true, "ChatGPT app-server is desktop process evidence")
        assertBool(SessionStateRules.isDesktopHostCommand(
            "/usr/local/bin/codex"
        ), false, "CLI codex process is not desktop process evidence")

        assertEqual(SessionStateRules.effectiveState(SessionStateRuleInput(
            state: "tool",
            startedAt: now - 500,
            ts: now - 60,
            isDesktop: false,
            codexRunning: false,
            hasLivePid: true,
            transcriptTerminalState: .none,
            now: now
        )), "tool", "tool remains tool before long-running threshold even when turn is old")

        assertEqual(SessionStateRules.effectiveState(SessionStateRuleInput(
            state: "tool",
            startedAt: now - 500,
            ts: now - 181,
            isDesktop: false,
            codexRunning: false,
            hasLivePid: true,
            transcriptTerminalState: .none,
            now: now
        )), "tool", "long-running tool keeps the persisted tool state")

        assertBool(SessionStateRules.isLongRunningTool(
            state: "tool",
            ts: now - 181,
            now: now
        ), true, "long-running tool requests icon warning")

        assertBool(SessionStateRules.isLongRunningTool(
            state: "tool",
            ts: now - 60,
            now: now
        ), false, "short tool does not request icon warning")

        assertEqual(SessionStateRules.effectiveState(SessionStateRuleInput(
            state: "thinking",
            startedAt: now - 181,
            ts: now - 181,
            isDesktop: false,
            codexRunning: false,
            hasLivePid: true,
            transcriptTerminalState: .none,
            now: now
        )), "thinking", "PostToolUse thinking is not rewritten as long-running")

        assertEqual(SessionStateRules.effectiveState(SessionStateRuleInput(
            state: "thinking",
            startedAt: now - 10,
            ts: now - 10,
            isDesktop: false,
            codexRunning: false,
            hasLivePid: true,
            transcriptTerminalState: .interrupted,
            now: now
        )), "idle", "interrupted thinking becomes idle")

        assertEqual(SessionStateRules.effectiveState(SessionStateRuleInput(
            state: "tool",
            startedAt: now - 10,
            ts: now - 10,
            isDesktop: false,
            codexRunning: false,
            hasLivePid: true,
            transcriptTerminalState: .interrupted,
            now: now
        )), "idle", "interrupted tool becomes idle")

        assertEqual(SessionStateRules.effectiveState(SessionStateRuleInput(
            state: "tool",
            startedAt: now - 901,
            ts: now - 901,
            isDesktop: true,
            codexRunning: true,
            hasLivePid: false,
            transcriptTerminalState: .none,
            now: now
        )), "waiting", "stale desktop active session becomes waiting")

        assertEqual(SessionStateRules.effectiveState(SessionStateRuleInput(
            state: "tool",
            startedAt: now - 60,
            ts: now - 60,
            isDesktop: true,
            codexRunning: false,
            hasLivePid: false,
            transcriptTerminalState: .none,
            now: now
        )), "idle", "desktop session becomes idle when Codex app is gone")

        assertEqual(SessionStateRules.effectiveState(SessionStateRuleInput(
            state: "tool",
            startedAt: now - 901,
            ts: now - 901,
            isDesktop: false,
            codexRunning: false,
            hasLivePid: false,
            transcriptTerminalState: .none,
            now: now
        )), "idle", "stale CLI active session without live pid becomes idle")

        assertEqual(SessionStateRules.effectiveState(SessionStateRuleInput(
            state: "thinking",
            startedAt: now - 60,
            ts: now - 60,
            isDesktop: true,
            codexRunning: true,
            hasLivePid: false,
            transcriptTerminalState: .completed,
            now: now
        )), "done", "transcript completion ends active desktop state when Stop hook is missing")

        let retention = SessionStateRules.sessionRetentionAfter
        let retentionNow = retention + 10_000
        assertBool(SessionStateRules.shouldRemoveSession(
            ts: retentionNow - retention + 1,
            now: retentionNow
        ), false, "session inside seven-day retention is retained")

        assertBool(SessionStateRules.shouldRemoveSession(
            ts: retentionNow - retention - 1,
            now: retentionNow
        ), true, "session older than seven days is removed")

        assertBool(SessionStateRules.shouldRemoveSession(
            ts: 0,
            now: now
        ), false, "session without a timestamp is not age-pruned")

        let visibilityNow = 100_000.0
        let fortyMinutesAgo = visibilityNow - 40 * 60
        assertBool(SessionStateRules.shouldHideSession(
            effectiveState: "done",
            ts: fortyMinutesAgo,
            now: visibilityNow,
            visibilityAfter: 30 * 60
        ), true, "forty-minute resting session is hidden by thirty-minute visibility")

        assertBool(SessionStateRules.shouldHideSession(
            effectiveState: "done",
            ts: fortyMinutesAgo,
            now: visibilityNow,
            visibilityAfter: 60 * 60
        ), false, "increasing visibility to one hour restores the session")

        assertBool(SessionStateRules.shouldHideSession(
            effectiveState: "done",
            ts: fortyMinutesAgo,
            now: visibilityNow,
            visibilityAfter: 24 * 60 * 60
        ), false, "increasing visibility to twenty-four hours restores the session")

        assertBool(SessionStateRules.shouldHideSession(
            effectiveState: "thinking",
            ts: visibilityNow - 2 * 24 * 60 * 60,
            now: visibilityNow,
            visibilityAfter: 30 * 60
        ), false, "active session is not hidden by resting visibility")

        print("PASS Swift state rules")
    }
}
`);
}

try {
  writeVerifier();
  cp.execFileSync("/usr/bin/swiftc", [
    path.join(repoRoot, "Sources", "NotificationSoundRules.swift"),
    path.join(repoRoot, "Sources", "SessionIndexStore.swift"),
    path.join(repoRoot, "Sources", "SessionVisibilityRules.swift"),
    path.join(repoRoot, "Sources", "TranscriptStateRules.swift"),
    path.join(repoRoot, "Sources", "SessionStateRules.swift"),
    verifier,
    "-o",
    binary,
  ], { stdio: "inherit" });
  cp.execFileSync(binary, { stdio: "inherit" });
} finally {
  fs.rmSync(tmp, { recursive: true, force: true });
}
