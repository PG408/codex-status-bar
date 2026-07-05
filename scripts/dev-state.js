#!/usr/bin/env node
const fs = require("fs");
const os = require("os");
const path = require("path");

const stateArg = process.argv[2] || "thinking";
const labelArg = process.argv.slice(3).join(" ");
const dir = process.env.CODEX_STATUSBAR_DIR || path.join(os.homedir(), ".codex", "statusbar");
const sessionId = process.env.CODEX_STATUSBAR_DEV_SESSION_ID || "dev";
const stateDir = process.env.CODEX_STATUSBAR_STATE_DIR || path.join(dir, "state.d");
const statePath = path.join(stateDir, `${sessionId}.json`);

const labels = {
  idle: "",
  done: "Done",
  thinking: "Thinking",
  tool: "Running cmd",
  compacting: "Compacting",
  permission: "Awaiting permission",
  waiting: "Waiting",
};

const aliases = {
  subagent: { state: "thinking", label: "Subagent", tool: "Task", activity: "subagent" },
  "subagent-permission": { state: "permission", label: "Subagent permission", tool: "Task", activity: "subagent" },
};

if (stateArg === "latency") {
  console.log("Writing alternating states every 1000ms. Watch the menu bar; updates should appear within ~0.4-0.8s.");
  let index = 0;
  const sequence = [
    ["thinking", "Latency thinking"],
    ["tool", "Latency tool"],
    ["compacting", "Latency compacting"],
    ["permission", "Latency permission"],
    ["idle", ""],
  ];
  setInterval(() => {
    const [state, label] = sequence[index % sequence.length];
    writeState(state, label);
    index += 1;
  }, 1000);
  return;
}

if (
  stateArg !== "demo"
  && !Object.prototype.hasOwnProperty.call(labels, stateArg)
  && !Object.prototype.hasOwnProperty.call(aliases, stateArg)
) {
  console.error(`Unknown state: ${stateArg}`);
  console.error("Use one of: idle, done, thinking, tool, compacting, permission, waiting, subagent, subagent-permission, demo, latency");
  process.exit(2);
}

function defaultToolFor(state) {
  if (state === "tool") return "Bash";
  if (state === "compacting") return "Compact";
  return "";
}

function writeState(state, label, options = {}) {
  const now = Math.floor(Date.now() / 1000);
  const startedAt = state === "thinking" || state === "tool" || state === "compacting" ? now : 0;
  const out = {
    state,
    label: labelArg || label,
    tool: options.tool || defaultToolFor(state),
    activity: options.activity || "",
    project: path.basename(process.cwd()),
    sessionId,
    turnId: state === "idle" || state === "done" ? "" : "dev-turn",
    pid: process.ppid,
    entrypoint: "dev",
    termProgram: process.env.TERM_PROGRAM || "",
    started: state !== "idle",
    startedAt,
    ts: now,
  };
  fs.mkdirSync(path.dirname(statePath), { recursive: true });
  const tmp = `${statePath}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(out, null, 2));
  fs.renameSync(tmp, statePath);
  console.log(`${new Date().toISOString()} ${statePath}: ${state}`);
}

async function demo() {
  const delayMs = Number(process.env.CODEX_STATUSBAR_DEMO_DELAY_MS || 1600);
  const sequence = [
    ["thinking", "Thinking", {}],
    ["tool", "Running cmd", {}],
    ["compacting", "Compacting", {}],
    ["thinking", "Subagent", { tool: "Task", activity: "subagent" }],
    ["permission", "Subagent permission", { tool: "Task", activity: "subagent" }],
    ["thinking", "Thinking", {}],
    ["permission", "Awaiting permission", {}],
    ["tool", "Editing", { tool: "apply_patch" }],
    ["done", "Done", {}],
    ["idle", "", {}],
  ];
  for (const [state, label, options] of sequence) {
    writeState(state, label, options);
    await new Promise((resolve) => setTimeout(resolve, delayMs));
  }
}

if (stateArg === "demo") {
  demo().catch((error) => {
    console.error(error);
    process.exit(1);
  });
} else {
  const status = aliases[stateArg] || { state: stateArg, label: labels[stateArg] };
  writeState(status.state, status.label, { tool: status.tool, activity: status.activity });
}
