#!/usr/bin/env node
const assert = require("assert");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { DEFAULT_THREAD_NAME, latestThreadName } = require("./lib/session-index");

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "codex-session-index-"));
try {
  const indexPath = path.join(tmp, "session_index.jsonl");
  fs.writeFileSync(indexPath, [
    JSON.stringify({ id: "a", thread_name: "旧名称", updated_at: "2026-01-01T00:00:00Z" }),
    JSON.stringify({ id: "b", thread_name: "另一个会话", updated_at: "2026-01-01T00:00:01Z" }),
    JSON.stringify({ id: "a", thread_name: "最新名称", updated_at: "2026-01-01T00:00:02Z" }),
    "{bad json",
  ].join("\n"));

  assert.equal(latestThreadName("a", { CODEX_SESSION_INDEX_PATH: indexPath }), "最新名称");
  assert.equal(latestThreadName("missing", { CODEX_SESSION_INDEX_PATH: indexPath }), DEFAULT_THREAD_NAME);
  assert.equal(latestThreadName("a", { CODEX_SESSION_INDEX_PATH: path.join(tmp, "missing.jsonl") }), DEFAULT_THREAD_NAME);
  console.log("PASS session_index latest thread name");
} finally {
  fs.rmSync(tmp, { recursive: true, force: true });
}
