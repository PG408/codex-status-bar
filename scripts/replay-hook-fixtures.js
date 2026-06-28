#!/usr/bin/env node
const cp = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const writerPath = path.join(repoRoot, "scripts", "codex-status-writer.js");
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

function runWriter(event, payload, stateDir) {
  const result = cp.spawnSync(process.execPath, [writerPath, event], {
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

function readState(stateDir) {
  const statePath = path.join(stateDir, "state.json");
  return readJson(statePath);
}

function assertExpected(actual, expected, fixtureName, stepIndex) {
  for (const [key, value] of Object.entries(expected || {})) {
    if (actual[key] !== value) {
      throw new Error(
        `${fixtureName} step ${stepIndex + 1}: expected ${key}=${JSON.stringify(value)}, got ${JSON.stringify(actual[key])}\n` +
          `actual=${JSON.stringify(actual, null, 2)}`
      );
    }
  }
}

function runFixture(filePath) {
  const fixture = readJson(filePath);
  const stateDir = fs.mkdtempSync(path.join(os.tmpdir(), `codex-statusbar-${fixture.name}-`));
  try {
    fixture.steps.forEach((step, index) => {
      runWriter(step.event, step.payload || {}, stateDir);
      const actual = readState(stateDir);
      assertExpected(actual, step.expect || {}, fixture.name, index);
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
