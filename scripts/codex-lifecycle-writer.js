#!/usr/bin/env node
const fs = require("fs");
const os = require("os");
const path = require("path");
const { ensureStatusBarRunning, parseAppPathArg } = require("./lib/hook-manager");
const { hasSessionIndexEntry, latestThreadName } = require("./lib/session-index");
const { resolveSessionSurface } = require("./lib/session-surface");
const { shouldSuppressSession } = require("./lib/session-visibility");
const { readTaskRecord } = require("./lib/task-record");

const event = process.argv[2] || "unknown";
const appPath = parseAppPathArg();
const home = os.homedir();
const dir = process.env.CODEX_STATUSBAR_DIR || path.join(home, ".codex", "statusbar");
const stateDir = path.join(dir, "state.d");

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

function writeJsonAtomic(filePath, object) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  const tmp = `${filePath}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(object, null, 2));
  fs.renameSync(tmp, filePath);
}

function sessionIdFor(payload) {
  return safeId(payload.session_id || payload.sessionId);
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

function run() {
  if (done) return;
  done = true;

  let payload = {};
  try {
    payload = JSON.parse(raw || "{}");
  } catch {
    payload = {};
  }

  const sessionId = sessionIdFor(payload);
  const statePath = statePathFor(sessionId);
  const prev = readPrevious(sessionId);
  const transcriptPath = typeof payload.transcript_path === "string"
    ? payload.transcript_path
    : prev.transcript || "";

  if (shouldSuppressSession({
    transcriptPath,
    isInSessionIndex: hasSessionIndexEntry(sessionId),
  })) {
    fs.rmSync(statePath, { force: true });
    process.exit(0);
  }

  if (event === "SessionStart") {
    const now = Date.now() / 1000;
    const pid = Number(process.ppid || 0);
    const surface = resolveSessionSurface(payload, {}, process.env, { pid, sessionId });
    const afterCompaction = payload.source === "compact" || prev.state === "compacting";
    const taskRecord = readTaskRecord(transcriptPath, "", null, true) ||
      (afterCompaction ? prev.taskRecord : null);
    const previousMain = prev.statusFacts?.main;
    const fallbackMain = afterCompaction && !taskRecord && previousMain?.startedAt > 0
      ? previousMain : null;
    const restoring = afterCompaction &&
      ((taskRecord?.state === "running" && taskRecord.startedAt > 0) || Boolean(fallbackMain));
    const main = {
      state: "thinking", label: "Thinking", tool: "",
      turnId: taskRecord?.turnId || fallbackMain?.turnId || "",
      startedAt: taskRecord?.startedAt || fallbackMain?.startedAt || 0,
    };
    const sameTurn = previousMain?.turnId === main.turnId;
    const pendingUserInputs = sameTurn ? prev.statusFacts.pendingUserInputs || {} : {};
    const legacyNeedsInput = sameTurn && previousMain?.state === "needs_input";
    const needsInput = restoring && (legacyNeedsInput || Object.keys(pendingUserInputs).length > 0);
    if (legacyNeedsInput) {
      main.state = "needs_input";
      main.label = "Needs input";
      main.tool = "request_user_input";
    }
    writeJsonAtomic(statePath, {
      state: restoring ? (needsInput ? "needs_input" : "thinking") : "idle",
      label: restoring ? (needsInput ? "Needs input" : "Thinking") : "",
      tool: needsInput ? "request_user_input" : "",
      threadName: latestThreadName(sessionId),
      project: basename(payload.cwd || payload.working_directory || payload.current_working_directory),
      sessionId,
      turnId: restoring ? main.turnId : "",
      pid,
      entrypoint: surface.entrypoint,
      entrypointSource: surface.entrypointSource,
      termProgram: surface.termProgram,
      focusTarget: surface.focusTarget,
      transcript: transcriptPath,
      started: restoring,
      startedAt: restoring && !needsInput ? main.startedAt : 0,
      ts: now,
      taskRecord,
      ...(restoring ? {
        statusFacts: {
          main,
          subagents: sameTurn ? prev.statusFacts.subagents || {} : {},
          pendingUserInputs,
        },
      } : {}),
    });
    ensureStatusBarRunning({ scriptDir: __dirname, appPath });
  } else if (event === "SessionEnd") {
    if (prev.sessionId) {
      const now = Date.now() / 1000;
      const pid = Number(prev.pid || process.ppid || 0);
      const surface = resolveSessionSurface(payload, prev, process.env, { pid, sessionId });
      writeJsonAtomic(statePath, {
        ...prev,
        state: "done",
        label: "Done",
        tool: "",
        threadName: latestThreadName(sessionId),
        project: basename(payload.cwd || payload.working_directory || payload.current_working_directory) || prev.project || "",
        sessionId,
        turnId: "",
        pid,
        entrypoint: surface.entrypoint,
        entrypointSource: surface.entrypointSource,
        termProgram: surface.termProgram,
        focusTarget: surface.focusTarget,
        transcript: transcriptPath,
        started: false,
        startedAt: 0,
        ts: now,
        taskRecord: readTaskRecord(
          transcriptPath, prev.statusFacts?.main?.turnId || prev.turnId || "", prev.taskRecord, true
        ),
      });
    }
  }

  process.exit(0);
}
