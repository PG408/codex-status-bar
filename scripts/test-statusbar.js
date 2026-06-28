#!/usr/bin/env node
const fs = require("fs");
const os = require("os");
const path = require("path");
const readline = require("readline");

const dir = process.env.CODEX_STATUSBAR_DIR || path.join(os.homedir(), ".codex", "statusbar");
const sessionId = process.env.CODEX_STATUSBAR_TEST_SESSION_ID || "manual-test";
const stateDir = process.env.CODEX_STATUSBAR_STATE_DIR || path.join(dir, "state.d");
const statePath = path.join(stateDir, `${sessionId}.json`);
const stepDelayMs = Number(process.env.CODEX_STATUSBAR_TEST_DELAY_MS || 1200);

const pipedAnswers = process.stdin.isTTY ? [] : fs.readFileSync(0, "utf8").split(/\r?\n/);
const rl = process.stdin.isTTY
  ? readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    })
  : null;

const results = [];

function nowSeconds() {
  return Math.floor(Date.now() / 1000);
}

function writeState(state, label, tool = "") {
  const now = nowSeconds();
  const out = {
    state,
    label,
    tool,
    project: path.basename(process.cwd()),
    sessionId,
    turnId: state === "idle" || state === "done" ? "" : "manual-turn",
    pid: process.ppid,
    entrypoint: "manual",
    started: state !== "idle",
    startedAt: state === "thinking" || state === "tool" ? now : 0,
    ts: now,
  };
  fs.mkdirSync(path.dirname(statePath), { recursive: true });
  const tmp = `${statePath}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(out, null, 2));
  fs.renameSync(tmp, statePath);
  console.log(`${new Date().toISOString()} wrote ${state}: ${label || "(no label)"}`);
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function ask(question) {
  if (!rl) {
    const answer = pipedAnswers.shift() || "n";
    console.log(`${question} [y/n/s=skip] ${answer}`);
    return Promise.resolve(answer.trim().toLowerCase() || "n");
  }
  return new Promise((resolve) => {
    rl.question(`${question} [y/n/s=skip] `, (answer) => {
      const normalized = answer.trim().toLowerCase();
      resolve(normalized || "n");
    });
  });
}

async function runStep(step) {
  console.log("");
  console.log(`STEP ${step.id}: ${step.name}`);
  console.log(`Expected: ${step.expected}`);
  writeState(step.state, step.label, step.tool);
  await wait(stepDelayMs);
  const answer = await ask("Did the menu bar match?");
  const status = answer.startsWith("y") ? "PASS" : answer.startsWith("s") ? "SKIP" : "FAIL";
  results.push({ ...step, status });
  console.log(`Recorded: ${status}`);
}

async function main() {
  const steps = [
    {
      id: 1,
      name: "Idle baseline",
      state: "idle",
      label: "",
      expected: "Only the green Codex icon is visible; no text and no timer.",
    },
    {
      id: 2,
      name: "Thinking with timer",
      state: "thinking",
      label: "Test thinking",
      expected: "Green icon plus 'Test thinking' and a timer that increments.",
    },
    {
      id: 3,
      name: "Tool label",
      state: "tool",
      label: "Running command",
      tool: "Bash",
      expected: "Blue-ish/active icon plus 'Running command' and a timer.",
    },
    {
      id: 4,
      name: "Permission",
      state: "permission",
      label: "Awaiting permission",
      expected: "Yellow dot plus 'Awaiting permission'; no timer.",
    },
    {
      id: 5,
      name: "Waiting",
      state: "waiting",
      label: "Waiting",
      expected: "Static icon plus 'Waiting'; no timer.",
    },
    {
      id: 6,
      name: "Done clears to resting icon",
      state: "done",
      label: "Done",
      expected: "Resting icon only; no 'Done' label remains.",
    },
  ];

  console.log("Codex Status Bar manual test");
  console.log(`State file: ${statePath}`);
  console.log(`Delay before each prompt: ${stepDelayMs}ms`);
  console.log("Answer based on what you see in the macOS menu bar.");

  for (const step of steps) {
    await runStep(step);
  }

  writeState("idle", "");

  console.log("");
  console.log("SUMMARY");
  for (const result of results) {
    console.log(`${result.status} step ${result.id}: ${result.name}`);
  }

  const failed = results.filter((result) => result.status === "FAIL");
  if (failed.length > 0) {
    console.log("");
    console.log("Failed steps:");
    for (const result of failed) {
      console.log(`- ${result.id}: expected ${result.expected}`);
    }
  }

  if (rl) rl.close();
  process.exit(failed.length > 0 ? 1 : 0);
}

main().catch((error) => {
  if (rl) rl.close();
  console.error(error);
  process.exit(1);
});
