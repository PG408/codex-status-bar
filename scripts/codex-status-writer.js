#!/usr/bin/env node
const fs = require("fs");
const os = require("os");
const path = require("path");
const { resolveSessionSurface } = require("./lib/session-surface");

const event = process.argv[2] || "unknown";
const home = os.homedir();
const dir = process.env.CODEX_STATUSBAR_DIR || path.join(home, ".codex", "statusbar");
const stateDir = path.join(dir, "state.d");
const debugLogPath = path.join(dir, "hooks-discovery.jsonl");
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
  return String(value || "").replace(/[^A-Za-z0-9_.-]/g, "").slice(0, 80) || "unknown";
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
      sessionId: sessionIdFor(payload),
      turnId: turnIdFor(payload),
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
  return safeId(payload.turn_id || payload.turnId || "");
}

function statePathFor(sessionId) {
  return path.join(stateDir, `${safeId(sessionId)}.json`);
}

function readPrevious(sessionId) {
  try {
    return JSON.parse(fs.readFileSync(statePathFor(sessionId), "utf8"));
  } catch {
    return {};
  }
}

function isActiveTurn(payload, prev) {
  const turnId = turnIdFor(payload);
  if (!turnId || !prev.turnId) return Boolean(prev.sessionId);
  return turnId === prev.turnId;
}

function stateFor(payload, prev, now, startedAt, state, label, toolName) {
  const sessionId = sessionIdFor(payload);
  const incomingTurnId = turnIdFor(payload);
  const pid = Number(prev.pid || process.ppid || 0);
  const surface = resolveSessionSurface(payload, prev, process.env, { pid });
  return {
    state,
    label,
    tool: toolName,
    project: basename(payload.cwd || payload.working_directory || payload.current_working_directory) || prev.project || "",
    sessionId,
    turnId: incomingTurnId || prev.turnId || "",
    pid,
    entrypoint: surface.entrypoint,
    entrypointSource: surface.entrypointSource,
    termProgram: surface.termProgram,
    focusTarget: surface.focusTarget,
    started: true,
    startedAt,
    ts: now,
  };
}

function wait(ms) {
  if (ms > 0) {
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
  }
}

function writeStateForEvent(payload) {
  const sessionId = sessionIdFor(payload);
  const nowMs = Date.now();
  const now = nowMs / 1000;
  const prev = readPrevious(sessionId);
  let startedAt = Number(prev.startedAt || 0);
  const toolName = typeof payload.tool_name === "string" ? payload.tool_name : "";

  switch (event) {
    case "UserPromptSubmit":
    case "SubagentStart": {
      startedAt = now;
      writeJsonAtomic(
        statePathFor(sessionId),
        stateFor(payload, prev, now, startedAt, "thinking", "Codex thinking", toolName)
      );
      return;
    }
    case "PreToolUse": {
      if (!isActiveTurn(payload, prev)) return;
      if (!startedAt) startedAt = now;
      writeJsonAtomic(statePathFor(sessionId), {
        ...stateFor(payload, prev, now, startedAt, "tool", labelForTool(toolName), toolName),
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
      const afterWaitNow = Date.now() / 1000;
      if (!startedAt) startedAt = afterWaitNow;
      writeJsonAtomic(
        statePathFor(sessionId),
        stateFor(payload, prev, afterWaitNow, startedAt, "thinking", "Codex thinking", toolName)
      );
      return;
    }
    case "PermissionRequest":
      writeJsonAtomic(statePathFor(sessionId), {
        ...stateFor(payload, prev, now, 0, "permission", "Awaiting permission", toolName),
        minVisibleUntilMs: nowMs + minPermissionVisibleMs,
      });
      return;
    case "Stop":
    case "SubagentStop":
      if (!isActiveTurn(payload, prev)) return;
      writeJsonAtomic(
        statePathFor(sessionId),
        stateFor(payload, prev, now, 0, "done", "Done", toolName)
      );
      return;
    case "SessionStart":
    case "SessionEnd":
    default:
      return;
  }
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
