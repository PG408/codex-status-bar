#!/usr/bin/env node
const fs = require("fs");
const os = require("os");
const path = require("path");

const event = process.argv[2] || "unknown";
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

function entrypointFor(payload) {
  if (typeof payload.entrypoint === "string" && payload.entrypoint) return payload.entrypoint;
  if (typeof payload.entry_point === "string" && payload.entry_point) return payload.entry_point;
  if (process.env.CODEX_STATUSBAR_ENTRYPOINT) return process.env.CODEX_STATUSBAR_ENTRYPOINT;
  if (process.env.CODEX_ENTRYPOINT) return process.env.CODEX_ENTRYPOINT;
  return process.env.TERM_PROGRAM ? "cli" : "";
}

function termProgramFor(payload) {
  if (typeof payload.term_program === "string" && payload.term_program) return payload.term_program;
  if (typeof payload.termProgram === "string" && payload.termProgram) return payload.termProgram;
  return process.env.TERM_PROGRAM || "";
}

function statePathFor(sessionId) {
  return path.join(stateDir, `${safeId(sessionId)}.json`);
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

  if (event === "SessionStart") {
    const now = Date.now() / 1000;
    writeJsonAtomic(statePath, {
      state: "idle",
      label: "",
      tool: "",
      project: basename(payload.cwd || payload.working_directory || payload.current_working_directory),
      sessionId,
      turnId: "",
      pid: Number(process.ppid || 0),
      entrypoint: entrypointFor(payload),
      termProgram: termProgramFor(payload),
      started: false,
      startedAt: 0,
      ts: now,
    });
  } else if (event === "SessionEnd") {
    fs.rmSync(statePath, { force: true });
  }

  process.exit(0);
}
