#!/usr/bin/env node
const cp = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const writerPath = path.join(repoRoot, "scripts", "codex-status-writer.js");
const lifecycleWriterPath = path.join(repoRoot, "scripts", "codex-lifecycle-writer.js");
const fixturesDir = path.join(repoRoot, "fixtures", "hook-events");
const selected = process.argv.slice(2);

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function fixturePaths() {
  const names = selected.length > 0
    ? selected
    : fs.readdirSync(fixturesDir).filter((name) => name.endsWith(".json")).sort();
  return names.map((name) => path.isAbsolute(name) ? name : path.join(fixturesDir, name));
}

function writerFor(step) {
  return step.writer === "lifecycle" ? lifecycleWriterPath : writerPath;
}

function runWriter(step, stateDir) {
  const event = step.event;
  const payload = step.payload || {};
  const result = cp.spawnSync(process.execPath, [writerFor(step), event], {
    input: JSON.stringify(payload),
    encoding: "utf8",
    env: {
      ...process.env,
      CODEX_STATUSBAR_DIR: stateDir,
      CODEX_STATUSBAR_MIN_TOOL_VISIBLE_MS: "0",
      CODEX_STATUSBAR_MAX_TOOL_VISIBLE_MS: "0",
      CODEX_STATUSBAR_MIN_PERMISSION_VISIBLE_MS: "0",
    },
  });

  if (result.status !== 0) {
    throw new Error(`writer failed for ${event}: ${result.stderr || result.stdout}`);
  }
}

function readSessions(stateDir) {
  const stateDirPath = path.join(stateDir, "state.d");
  const sessions = {};
  if (!fs.existsSync(stateDirPath)) return sessions;
  for (const name of fs.readdirSync(stateDirPath).filter((entry) => entry.endsWith(".json")).sort()) {
    const id = path.basename(name, ".json");
    sessions[id] = readJson(path.join(stateDirPath, name));
  }
  return sessions;
}

function priority(session) {
  switch (session.state) {
    case "permission":
      return 2;
    case "thinking":
    case "tool":
      return 1;
    default:
      return 0;
  }
}

function leadSessionId(sessions) {
  const values = Object.values(sessions);
  if (values.length === 0) return "";
  values.sort((a, b) => {
    const pa = priority(a);
    const pb = priority(b);
    if (pa !== pb) return pb - pa;
    return Number(b.ts || 0) - Number(a.ts || 0);
  });
  return values[0].sessionId || "";
}

function assertExpected(actual, expected, fixtureName, stepIndex) {
  for (const [key, value] of Object.entries(expected || {})) {
    try {
      assertDeepEqual(actual[key], value);
    } catch {
      throw new Error(
        `${fixtureName} step ${stepIndex + 1}: expected ${key}=${JSON.stringify(value)}, got ${JSON.stringify(actual[key])}\n` +
          `actual=${JSON.stringify(actual, null, 2)}`
      );
    }
  }
}

function assertDeepEqual(actual, expected) {
  if (expected && typeof expected === "object") {
    if (JSON.stringify(actual) !== JSON.stringify(expected)) {
      throw new Error("not equal");
    }
    return;
  }
  if (actual !== expected) throw new Error("not equal");
}

function assertStep(stateDir, expected, fixtureName, stepIndex) {
  const sessions = readSessions(stateDir);
  const legacyPath = path.join(stateDir, "state.json");
  if (fs.existsSync(legacyPath)) {
    throw new Error(`${fixtureName} step ${stepIndex + 1}: legacy state.json should not be written`);
  }

  for (const [id, expectedSession] of Object.entries(expected.sessions || {})) {
    if (!sessions[id]) {
      throw new Error(`${fixtureName} step ${stepIndex + 1}: missing session file for ${id}`);
    }
    assertExpected(sessions[id], expectedSession, fixtureName, stepIndex);
  }

  for (const id of expected.absent || []) {
    if (sessions[id]) {
      throw new Error(`${fixtureName} step ${stepIndex + 1}: expected ${id} to be absent`);
    }
  }

  if (expected.lead !== undefined) {
    const actualLead = leadSessionId(sessions);
    if (actualLead !== expected.lead) {
      throw new Error(
        `${fixtureName} step ${stepIndex + 1}: expected lead=${expected.lead}, got ${actualLead}\n` +
          `sessions=${JSON.stringify(sessions, null, 2)}`
      );
    }
  }
}

function runFixture(filePath) {
  const fixture = readJson(filePath);
  const stateDir = fs.mkdtempSync(path.join(os.tmpdir(), `codex-statusbar-${fixture.name}-`));
  try {
    fixture.steps.forEach((step, index) => {
      runWriter(step, stateDir);
      assertStep(stateDir, step.expect || {}, fixture.name, index);
    });
    console.log(`PASS ${fixture.name}`);
  } finally {
    fs.rmSync(stateDir, { recursive: true, force: true });
  }
}

function main() {
  for (const filePath of fixturePaths()) {
    runFixture(filePath);
  }
}

try {
  main();
} catch (error) {
  console.error(error && error.stack ? error.stack : error);
  process.exit(1);
}
