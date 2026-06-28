#!/usr/bin/env node
const fs = require("fs");
const os = require("os");
const path = require("path");

const event = process.argv[2] || "unknown";
const home = os.homedir();
const dir = process.env.CODEX_STATUSBAR_DIR || path.join(home, ".codex", "statusbar");
const debugLogPath = path.join(dir, "hooks-discovery.jsonl");
const statePath = path.join(dir, "state.json");
const minToolVisibleMs = Number(process.env.CODEX_STATUSBAR_MIN_TOOL_VISIBLE_MS || 900);
const maxToolVisibleMs = Number(process.env.CODEX_STATUSBAR_MAX_TOOL_VISIBLE_MS || 8000);
const minPermissionVisibleMs = Number(process.env.CODEX_STATUSBAR_MIN_PERMISSION_VISIBLE_MS || 12000);
const debugEnabled = process.env.CODEX_STATUSBAR_DEBUG === "1";

let raw = "";
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", run);
process.stdin.on("error", run);
setTimeout(run, 1000);

let done = false;

function safeId(value) {
  return String(value || "").replace(/[^A-Za-z0-9_.-]/g, "").slice(0, 80);
}

function basename(value) {
  if (!value || typeof value !== "string") return "";
  return path.basename(value);
}

function typeOf(value) {
  if (Array.isArray(value)) return `array(${value.length})`;
  if (value === null) return "null";
  return typeof value;
}

function summarizePayload(payload) {
  const keys = Object.keys(payload).sort();
  const types = {};
  for (const key of keys) {
    types[key] = typeOf(payload[key]);
  }

  return {
    keys,
    types,
    safeValues: {
      cwdBasename: basename(payload.cwd || payload.working_directory || payload.current_working_directory),
      toolName: typeof payload.tool_name === "string" ? payload.tool_name : "",
      sessionId: safeId(payload.session_id || payload.sessionId),
      permissionMode: typeof payload.permission_mode === "string" ? payload.permission_mode : "",
      matcher: typeof payload.matcher === "string" ? payload.matcher : "",
    },
  };
}

function writeJsonAtomic(filePath, object) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  const tmp = `${filePath}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(object, null, 2));
  fs.renameSync(tmp, filePath);
}

function appendJsonl(filePath, object) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.appendFileSync(filePath, `${JSON.stringify(object)}\n`);
}

function labelForTool(toolName) {
  const labels = {
    Bash: "Running command",
    Shell: "Running command",
    LocalShell: "Running command",
    exec_command: "Running command",
    apply_patch: "Editing",
    Read: "Reading",
    Grep: "Searching",
    Glob: "Searching",
    WebFetch: "Browsing web",
    WebSearch: "Searching web",
    TodoWrite: "Planning",
  };
  return labels[toolName] || "Using tool";
}

function sessionIdFor(payload) {
  return safeId(payload.session_id || payload.sessionId);
}

function turnIdFor(payload) {
  return safeId(payload.turn_id || payload.turnId);
}

function isActiveTurn(payload, prev) {
  const sessionId = sessionIdFor(payload);
  const turnId = turnIdFor(payload);
  if (!sessionId || sessionId !== prev.activeSessionId) return false;
  if (turnId && prev.activeTurnId) return turnId === prev.activeTurnId;
  return Boolean(prev.activeSessionId);
}

function isActiveSession(payload, prev) {
  const sessionId = sessionIdFor(payload);
  if (!prev.activeSessionId) return true;
  return Boolean(sessionId && sessionId === prev.activeSessionId);
}

function baseState(payload, now, startedAt, state, label, toolName) {
  return {
    state,
    label,
    tool: toolName,
    project: basename(payload.cwd || payload.working_directory || payload.current_working_directory),
    sessionId: sessionIdFor(payload),
    startedAt,
    ts: now,
  };
}

function activeState(payload, now, startedAt, state, label, toolName) {
  return {
    ...baseState(payload, now, startedAt, state, label, toolName),
    activeSessionId: sessionIdFor(payload),
    activeTurnId: turnIdFor(payload),
  };
}

function wait(ms) {
  if (ms > 0) {
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
  }
}

function writeStateForEvent(payload) {
  const nowMs = Date.now();
  const now = Math.floor(nowMs / 1000);
  let prev = {};
  try {
    prev = JSON.parse(fs.readFileSync(statePath, "utf8"));
  } catch {}

  let state = "idle";
  let label = "";
  let startedAt = Number(prev.startedAt || 0);
  const toolName = typeof payload.tool_name === "string" ? payload.tool_name : "";

  switch (event) {
    case "UserPromptSubmit":
      state = "thinking";
      label = "Codex thinking";
      startedAt = now;
      writeJsonAtomic(statePath, activeState(payload, now, startedAt, state, label, toolName));
      return;
    case "PreToolUse": {
      if (!isActiveTurn(payload, prev)) return;
      state = "tool";
      label = labelForTool(toolName);
      if (!startedAt) startedAt = now;
      writeJsonAtomic(statePath, {
        ...activeState(payload, now, startedAt, state, label, toolName),
        visibleUntilMs: nowMs + maxToolVisibleMs,
        minVisibleUntilMs: nowMs + minToolVisibleMs,
      });
      return;
    }
    case "PostToolUse": {
      if (!isActiveTurn(payload, prev)) return;
      if (prev.state !== "permission") {
        const waitMs = Math.max(0, Number(prev.minVisibleUntilMs || prev.visibleUntilMs || 0) - nowMs);
        if (prev.state === "tool" && waitMs > 0) {
          wait(waitMs);
        }
      }
      const afterWaitNow = Math.floor(Date.now() / 1000);
      state = "thinking";
      label = "Codex thinking";
      if (!startedAt) startedAt = afterWaitNow;
      writeJsonAtomic(statePath, activeState(payload, afterWaitNow, startedAt, state, label, toolName));
      return;
    }
    case "PermissionRequest":
      if (!isActiveSession(payload, prev)) return;
      state = "permission";
      label = "Awaiting permission";
      startedAt = 0;
      writeJsonAtomic(statePath, {
        ...activeState(payload, now, startedAt, state, label, toolName),
        minVisibleUntilMs: nowMs + minPermissionVisibleMs,
      });
      return;
    case "Stop":
    case "SubagentStop":
      if (!isActiveTurn(payload, prev)) return;
      state = "done";
      label = "Done";
      startedAt = 0;
      break;
    case "SessionStart":
    case "SubagentStart":
      return;
    default:
      return;
  }

  writeJsonAtomic(statePath, baseState(payload, now, startedAt, state, label, toolName));
}

function run() {
  if (done) return;
  done = true;

  let payload = {};
  try {
    payload = JSON.parse(raw || "{}");
  } catch {
    payload = {};
  }

  try {
    if (debugEnabled) {
      appendJsonl(debugLogPath, {
        ts: new Date().toISOString(),
        event,
        rawBytes: Buffer.byteLength(raw || "", "utf8"),
        ...summarizePayload(payload),
      });
    }
    writeStateForEvent(payload);
  } catch (error) {
    if (debugEnabled) {
      try {
        appendJsonl(debugLogPath, {
          ts: new Date().toISOString(),
          event,
          error: String(error && error.message ? error.message : error),
        });
      } catch {}
    }
  }

  process.exit(0);
}
