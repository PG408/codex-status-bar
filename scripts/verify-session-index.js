#!/usr/bin/env node
const assert = require("assert");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { DEFAULT_THREAD_NAME, hasSessionIndexEntry, latestThreadName } = require("./lib/session-index");

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "codex-session-index-"));
try {
  const indexPath = path.join(tmp, "session_index.jsonl");
  const globalStatePath = path.join(tmp, "global-state.json");
  const malformedGlobalStatePath = path.join(tmp, "malformed-global-state.json");
  fs.writeFileSync(indexPath, [
    JSON.stringify({ id: "a", thread_name: "旧名称", updated_at: "2026-01-01T00:00:00Z" }),
    JSON.stringify({ id: "b", thread_name: "另一个会话", updated_at: "2026-01-01T00:00:01Z" }),
    JSON.stringify({ id: "a", thread_name: "最新名称", updated_at: "2026-01-01T00:00:02Z" }),
    "{bad json",
  ].join("\n"));
  fs.writeFileSync(globalStatePath, JSON.stringify({
    "electron-persisted-atom-state": {
      "prompt-history": {
        side: ["Side chat prompt"],
        a: ["Formal thread prompt"],
      },
    },
  }));
  fs.writeFileSync(malformedGlobalStatePath, "{bad json");

  assert.equal(latestThreadName("a", { CODEX_SESSION_INDEX_PATH: indexPath }), "最新名称");
  assert.equal(hasSessionIndexEntry("a", { CODEX_SESSION_INDEX_PATH: indexPath }), true);
  assert.equal(hasSessionIndexEntry("missing", { CODEX_SESSION_INDEX_PATH: indexPath }), false);
  assert.equal(latestThreadName("missing", { CODEX_SESSION_INDEX_PATH: indexPath }), DEFAULT_THREAD_NAME);
  assert.equal(latestThreadName("a", { CODEX_SESSION_INDEX_PATH: path.join(tmp, "missing.jsonl") }), DEFAULT_THREAD_NAME);
  assert.equal(latestThreadName("side", {
    CODEX_SESSION_INDEX_PATH: indexPath,
    CODEX_GLOBAL_STATE_PATH: globalStatePath,
  }), "Side Chat");
  assert.equal(latestThreadName("a", {
    CODEX_SESSION_INDEX_PATH: indexPath,
    CODEX_GLOBAL_STATE_PATH: globalStatePath,
  }), "最新名称");
  assert.equal(latestThreadName("side", {
    CODEX_SESSION_INDEX_PATH: indexPath,
    CODEX_GLOBAL_STATE_PATH: malformedGlobalStatePath,
  }), DEFAULT_THREAD_NAME);
  console.log("PASS session_index latest thread name");
} finally {
  fs.rmSync(tmp, { recursive: true, force: true });
}
