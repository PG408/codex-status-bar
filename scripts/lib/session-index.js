const fs = require("fs");
const os = require("os");
const path = require("path");

const DEFAULT_THREAD_NAME = "无法获取 thread 名称";

function sessionIndexPath(env = process.env) {
  return env.CODEX_SESSION_INDEX_PATH || path.join(os.homedir(), ".codex", "session_index.jsonl");
}

function latestThreadName(sessionId, env = process.env) {
  if (!sessionId) return DEFAULT_THREAD_NAME;

  let latest = "";
  try {
    const text = fs.readFileSync(sessionIndexPath(env), "utf8");
    for (const line of text.split(/\n+/)) {
      if (!line) continue;
      let row;
      try {
        row = JSON.parse(line);
      } catch {
        continue;
      }
      if (row.id === sessionId && typeof row.thread_name === "string" && row.thread_name.trim()) {
        latest = row.thread_name.trim();
      }
    }
  } catch {
    return DEFAULT_THREAD_NAME;
  }

  return latest || DEFAULT_THREAD_NAME;
}

module.exports = {
  DEFAULT_THREAD_NAME,
  latestThreadName,
  sessionIndexPath,
};
