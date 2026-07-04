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

@main
struct VerifyStateRules {
    static func main() {
        let now = 10_000.0
        let interruptedLine = #"{"timestamp":"2026-06-30T05:17:42.067Z","type":"event_msg","payload":{"type":"turn_aborted","turn_id":"turn-1","reason":"interrupted","completed_at":1782796662,"duration_ms":3398}}"#
        let taskStartedLine = #"{"timestamp":"2026-06-30T05:18:05.174Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-2","started_at":1782796685}}"#

        assertBool(TranscriptStateRules.lineShowsUserInterrupt(interruptedLine), true, "turn_aborted interrupted event is a user interrupt")
        assertBool(TranscriptStateRules.lineShowsUserInterrupt(taskStartedLine), false, "task_started event is not a user interrupt")
        assertBool(TranscriptStateRules.lineShowsUserInterrupt("interrupted by user"), true, "legacy interrupted marker remains supported")

        assertEqual(SessionStateRules.effectiveState(SessionStateRuleInput(
            state: "tool",
            startedAt: now - 500,
            ts: now - 60,
            isDesktop: false,
            codexRunning: false,
            hasLivePid: true,
            interruptedByUser: false,
            now: now
        )), "tool", "tool remains tool before long-running threshold even when turn is old")

        assertEqual(SessionStateRules.effectiveState(SessionStateRuleInput(
            state: "tool",
            startedAt: now - 500,
            ts: now - 181,
            isDesktop: false,
            codexRunning: false,
            hasLivePid: true,
            interruptedByUser: false,
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
            interruptedByUser: false,
            now: now
        )), "thinking", "PostToolUse thinking is not rewritten as long-running")

        assertEqual(SessionStateRules.effectiveState(SessionStateRuleInput(
            state: "thinking",
            startedAt: now - 10,
            ts: now - 10,
            isDesktop: false,
            codexRunning: false,
            hasLivePid: true,
            interruptedByUser: true,
            now: now
        )), "idle", "interrupted thinking becomes idle")

        assertEqual(SessionStateRules.effectiveState(SessionStateRuleInput(
            state: "tool",
            startedAt: now - 10,
            ts: now - 10,
            isDesktop: false,
            codexRunning: false,
            hasLivePid: true,
            interruptedByUser: true,
            now: now
        )), "idle", "interrupted tool becomes idle")

        assertEqual(SessionStateRules.effectiveState(SessionStateRuleInput(
            state: "tool",
            startedAt: now - 901,
            ts: now - 901,
            isDesktop: true,
            codexRunning: true,
            hasLivePid: false,
            interruptedByUser: false,
            now: now
        )), "waiting", "stale desktop active session becomes waiting")

        assertEqual(SessionStateRules.effectiveState(SessionStateRuleInput(
            state: "tool",
            startedAt: now - 60,
            ts: now - 60,
            isDesktop: true,
            codexRunning: false,
            hasLivePid: false,
            interruptedByUser: false,
            now: now
        )), "idle", "desktop session becomes idle when Codex app is gone")

        assertEqual(SessionStateRules.effectiveState(SessionStateRuleInput(
            state: "tool",
            startedAt: now - 901,
            ts: now - 901,
            isDesktop: false,
            codexRunning: false,
            hasLivePid: false,
            interruptedByUser: false,
            now: now
        )), "idle", "stale CLI active session without live pid becomes idle")

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
