#!/usr/bin/env node
const cp = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "codex-transcript-turn-store-"));
const transcript = path.join(tmp, "child.jsonl");
const verifier = path.join(tmp, "VerifyTranscriptTurnStore.swift");
const binary = path.join(tmp, "verify-transcript-turn-store");

try {
  fs.writeFileSync(verifier, `
import Foundation

func assertTurn(_ actual: TranscriptTurnState, _ expected: TranscriptTurnState, _ label: String) {
    if actual != expected {
        fputs("FAIL \\(label): expected \\(expected), got \\(actual)\\n", stderr)
        exit(1)
    }
}

@main
struct VerifyTranscriptTurnStore {
    static func main() throws {
        let path = ${JSON.stringify(transcript)}
        let store = TranscriptTurnStore()
        try """
        {"timestamp":"2026-08-09T10:00:00.100Z","type":"event_msg","payload":{"type":"task_started","started_at":1}}
        """.write(toFile: path, atomically: true, encoding: .utf8)
        assertTurn(store.snapshot(for: path).state, .running, "task start is active")
        assertTurn(store.snapshot(for: path).state, .running, "unchanged file uses cached state")

        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("""
        {"timestamp":"2026-08-09T10:00:01.100Z","type":"event_msg","payload":{"type":"task_complete","completed_at":2}}

        """.utf8))
        try handle.close()
        assertTurn(store.snapshot(for: path).state, .completed, "appended completion is terminal")

        try """
        {"timestamp":"2026-08-09T10:00:02.100Z","type":"event_msg","payload":{"type":"task_started","started_at":3}}
        """.write(toFile: path, atomically: true, encoding: .utf8)
        assertTurn(store.snapshot(for: path).state, .running, "truncated transcript resets cached offset")

        let largePath = path + ".large"
        FileManager.default.createFile(atPath: largePath, contents: nil)
        let largeHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: largePath))
        try largeHandle.truncate(atOffset: 256 * 1024 * 1024)
        try largeHandle.seekToEnd()
        try largeHandle.write(contentsOf: Data("""

        {"timestamp":"2026-08-09T10:00:03.100Z","type":"event_msg","payload":{"type":"task_started","started_at":4}}

        """.utf8))
        try largeHandle.close()
        let startedAt = Date()
        assertTurn(store.snapshot(for: largePath).state, .running, "large transcript tail is parsed")
        let elapsed = Date().timeIntervalSince(startedAt)
        if elapsed > 0.2 {
            fputs("FAIL large transcript read blocked for \\(elapsed)s\\n", stderr)
            exit(1)
        }

        let largeBodyPath = path + ".large-body"
        FileManager.default.createFile(atPath: largeBodyPath, contents: nil)
        let largeBodyHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: largeBodyPath))
        try largeBodyHandle.write(contentsOf: Data("""
        {"timestamp":"2026-08-09T10:00:04.100Z","type":"event_msg","payload":{"type":"task_started","started_at":5}}

        """.utf8))
        try largeBodyHandle.truncate(atOffset: 256 * 1024 * 1024)
        try largeBodyHandle.seekToEnd()
        try largeBodyHandle.write(contentsOf: Data("\\n".utf8))
        try largeBodyHandle.close()
        assertTurn(
            store.snapshot(for: largeBodyPath).state,
            .running,
            "large first turn keeps task_started from the bounded head"
        )
        print("PASS transcript turn store")
    }
}
`);

  cp.execFileSync("/usr/bin/swiftc", [
    path.join(repoRoot, "Sources", "TranscriptStateRules.swift"),
    path.join(repoRoot, "Sources", "TranscriptTurnStore.swift"),
    verifier,
    "-o",
    binary,
  ], { stdio: "inherit" });
  cp.execFileSync(binary, { stdio: "inherit" });
} finally {
  fs.rmSync(tmp, { recursive: true, force: true });
}
