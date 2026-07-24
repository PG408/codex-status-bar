#!/usr/bin/env node
const assert = require("assert");
const cp = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { shouldSuppressSession } = require("./lib/session-visibility");

const repoRoot = path.resolve(__dirname, "..");
const writerPath = path.join(repoRoot, "scripts", "codex-status-writer.js");
const lifecycleWriterPath = path.join(repoRoot, "scripts", "codex-lifecycle-writer.js");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "codex-session-visibility-"));
const statusDir = path.join(tmp, "statusbar");
const stateDir = path.join(statusDir, "state.d");
const sessionIndexPath = path.join(tmp, "session_index.jsonl");

function statePath(sessionId) {
  return path.join(stateDir, `${sessionId}.json`);
}

function writeIndex(rows) {
  fs.writeFileSync(sessionIndexPath, rows.map((row) => JSON.stringify(row)).join("\n"));
}

function runWriter(writer, event, payload) {
  const result = cp.spawnSync(process.execPath, [writer, event], {
    input: JSON.stringify(payload),
    encoding: "utf8",
    env: {
      ...process.env,
      CODEX_SESSION_INDEX_PATH: sessionIndexPath,
      CODEX_STATUSBAR_DIR: statusDir,
      CODEX_STATUSBAR_MIN_TOOL_VISIBLE_MS: "0",
      CODEX_STATUSBAR_MAX_TOOL_VISIBLE_MS: "0",
      CODEX_STATUSBAR_MIN_PERMISSION_VISIBLE_MS: "0",
    },
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
}

try {
  assert.equal(shouldSuppressSession({ transcriptPath: "", isInSessionIndex: false }), true);
  assert.equal(shouldSuppressSession({ transcriptPath: " /tmp/session.jsonl ", isInSessionIndex: false }), false);
  assert.equal(shouldSuppressSession({ transcriptPath: "", isInSessionIndex: true }), false);
  assert.equal(shouldSuppressSession({ transcriptPath: "/tmp/session.jsonl", isInSessionIndex: true }), false);

  writeIndex([]);
  const transientId = "transient-session";
  fs.mkdirSync(stateDir, { recursive: true });
  fs.writeFileSync(statePath(transientId), JSON.stringify({ sessionId: transientId, state: "thinking" }));
  runWriter(writerPath, "Stop", { session_id: transientId });
  assert.equal(fs.existsSync(statePath(transientId)), false, "transient status event removes residual state");

  const transcriptId = "transcript-session";
  runWriter(writerPath, "UserPromptSubmit", {
    session_id: transcriptId,
    transcript_path: "/tmp/session.jsonl",
    prompt: "hello",
  });
  assert.equal(fs.existsSync(statePath(transcriptId)), true, "transcript keeps a session visible");

  const carriedTranscriptId = "carried-transcript-session";
  fs.writeFileSync(statePath(carriedTranscriptId), JSON.stringify({
    sessionId: carriedTranscriptId,
    state: "thinking",
    transcript: "/tmp/carried-session.jsonl",
  }));
  runWriter(writerPath, "Stop", { session_id: carriedTranscriptId });
  assert.equal(fs.existsSync(statePath(carriedTranscriptId)), true, "previous transcript remains a persistence signal");

  const indexedId = "indexed-session";
  writeIndex([{ id: indexedId, thread_name: "Indexed" }]);
  runWriter(writerPath, "UserPromptSubmit", { session_id: indexedId, prompt: "hello" });
  assert.equal(fs.existsSync(statePath(indexedId)), true, "session index keeps a session visible");
  runWriter(lifecycleWriterPath, "SessionStart", { session_id: indexedId });
  assert.equal(fs.existsSync(statePath(indexedId)), true, "lifecycle writer keeps an indexed session visible");

  const lifecycleId = "transient-lifecycle-session";
  fs.writeFileSync(statePath(lifecycleId), JSON.stringify({ sessionId: lifecycleId, state: "idle" }));
  runWriter(lifecycleWriterPath, "SessionEnd", { session_id: lifecycleId });
  assert.equal(fs.existsSync(statePath(lifecycleId)), false, "lifecycle writer removes transient residual state");

  console.log("PASS transient session visibility");
} finally {
  fs.rmSync(tmp, { recursive: true, force: true });
}
