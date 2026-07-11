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
        assertTerminal(TranscriptStateRules.terminalState(in: completedTail, after: 9_980), .completed, "task_complete after state timestamp ends the turn")
        assertTerminal(TranscriptStateRules.terminalState(in: interruptedTail, after: 9_980), .interrupted, "turn_aborted after state timestamp ends the turn")
        assertTerminal(TranscriptStateRules.terminalState(in: resumedTail, after: 9_980), .none, "newer task_started supersedes an older completion")
        assertTerminal(TranscriptStateRules.terminalState(in: completedTail, after: 9_999), .none, "completion before state timestamp is ignored")

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

        assertBool(SessionStateRules.shouldRemoveSession(
            state: "tool",
            effectiveState: "waiting",
            pid: 123,
            pidAlive: false,
            isDesktop: true,
            codexRunning: true,
            ts: now - 901,
            now: now
        ), false, "desktop app alive does not delete stale active session immediately")

        assertBool(SessionStateRules.shouldRemoveSession(
            state: "tool",
            effectiveState: "tool",
            pid: 123,
            pidAlive: false,
            isDesktop: true,
            codexRunning: false,
            ts: now - 60,
            now: now
        ), true, "desktop app exit removes desktop session")

        assertBool(SessionStateRules.shouldRemoveSession(
            state: "done",
            effectiveState: "done",
            pid: 123,
            pidAlive: false,
            isDesktop: true,
            codexRunning: true,
            ts: now - 301,
            now: now
        ), false, "completed desktop session is retained for the menu duration")

        assertBool(SessionStateRules.shouldRemoveSession(
            state: "done",
            effectiveState: "done",
            pid: 123,
            pidAlive: false,
            isDesktop: true,
            codexRunning: true,
            ts: now - 1801,
            now: now
        ), true, "completed desktop session is pruned after the menu duration")

        assertBool(SessionStateRules.shouldRemoveSession(
            state: "tool",
            effectiveState: "tool",
            pid: 123,
            pidAlive: false,
            isDesktop: false,
            codexRunning: false,
            ts: now - 60,
            now: now
        ), true, "CLI session with dead pid is removed")

        assertBool(SessionStateRules.shouldRemoveSession(
            state: "done",
            effectiveState: "done",
            pid: 123,
            pidAlive: false,
            isDesktop: false,
            codexRunning: false,
            ts: now - 301,
            now: now
        ), false, "completed CLI session with dead pid is retained for the menu duration")

        assertBool(SessionStateRules.shouldRemoveSession(
            state: "tool",
            effectiveState: "tool",
            pid: 123,
            pidAlive: true,
            isDesktop: false,
            codexRunning: false,
            ts: now - 901,
            now: now
        ), false, "CLI session with live pid is retained")

        print("PASS Swift state rules")
    }
}
`);
}

try {
  writeVerifier();
  cp.execFileSync("/usr/bin/swiftc", [
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
