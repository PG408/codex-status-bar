#!/usr/bin/env node
const assert = require("assert");
const cp = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const {
  EVENT_SPECS,
  MARKERS,
  desiredHookSettings,
  findNode,
  needsRepair,
  removeOwnHooks,
  repairHooks,
  resolveScriptPaths,
} = require("./lib/hook-manager");

const repoRoot = path.resolve(__dirname, "..");

function run(name, fn) {
  try {
    fn();
    console.log(`PASS ${name}`);
  } catch (error) {
    console.error(`FAIL ${name}`);
    console.error(error && error.stack ? error.stack : error);
    process.exitCode = 1;
  }
}

function makeTempDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "codex-statusbar-hooks-"));
}

function commandPaths(settings) {
  const commands = [];
  for (const groups of Object.values(settings.hooks || {})) {
    for (const group of groups || []) {
      for (const hook of group.hooks || []) {
        commands.push(hook.command || "");
      }
    }
  }
  return commands;
}

run("findNode prefers explicit current exec path", () => {
  const dir = makeTempDir();
  try {
    const node = path.join(dir, "node");
    fs.writeFileSync(node, "");
    fs.chmodSync(node, 0o755);
    const found = findNode({
      currentExecPath: node,
      env: {},
      exists: (candidate) => candidate === node,
    });
    assert.equal(found, node);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

run("resolveScriptPaths supports bundled resources", () => {
  const root = makeTempDir();
  try {
    const resources = path.join(root, "CodexStatusBar.app", "Contents", "Resources");
    fs.mkdirSync(path.join(resources, "lib"), { recursive: true });
    fs.writeFileSync(path.join(resources, "codex-status-writer.js"), "");
    fs.writeFileSync(path.join(resources, "codex-lifecycle-writer.js"), "");
    fs.writeFileSync(path.join(resources, "install-codex-statusbar.js"), "");
    const paths = resolveScriptPaths({ scriptDir: resources, repoRoot });
    assert.equal(paths.writerPath, path.join(resources, "codex-status-writer.js"));
    assert.equal(paths.lifecyclePath, path.join(resources, "codex-lifecycle-writer.js"));
    assert.equal(paths.installPath, path.join(resources, "install-codex-statusbar.js"));
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

run("desiredHookSettings installs all Codex Status Bar events", () => {
  const settings = desiredHookSettings({
    existing: { hooks: {} },
    nodePath: "/opt/homebrew/bin/node",
    writerPath: "/app/codex-status-writer.js",
    lifecyclePath: "/app/codex-lifecycle-writer.js",
  });
  for (const spec of EVENT_SPECS) {
    assert.ok(settings.hooks[spec.event], `missing ${spec.event}`);
  }
  const commands = commandPaths(settings);
  assert.ok(commands.some((command) => command.includes("codex-lifecycle-writer.js") && command.includes("SessionStart")));
  assert.ok(commands.some((command) => command.includes("codex-status-writer.js") && command.includes("PreToolUse")));
});

run("repairHooks updates stale own hooks and preserves unrelated hooks", () => {
  const existing = {
    hooks: {
      UserPromptSubmit: [
        { hooks: [{ type: "command", command: "\"/old/node\" \"/old/codex-status-writer.js\" UserPromptSubmit" }] },
        { hooks: [{ type: "command", command: "echo user-hook" }] },
      ],
    },
  };
  const repaired = repairHooks(existing, {
    nodePath: "/new/node",
    writerPath: "/new/codex-status-writer.js",
    lifecyclePath: "/new/codex-lifecycle-writer.js",
  });
  const commands = commandPaths(repaired);
  assert.ok(commands.includes("echo user-hook"));
  assert.ok(commands.some((command) => command.includes("\"/new/node\"") && command.includes("/new/codex-status-writer.js")));
  assert.ok(!commands.some((command) => command.includes("/old/codex-status-writer.js")));
});

run("removeOwnHooks removes only marker commands", () => {
  const cleaned = removeOwnHooks({
    hooks: {
      Stop: [
        { hooks: [{ type: "command", command: "/x/codex-status-writer.js Stop" }] },
        { hooks: [{ type: "command", command: "echo keep-me" }] },
      ],
    },
  });
  assert.deepEqual(cleaned.hooks.Stop, [{ hooks: [{ type: "command", command: "echo keep-me" }] }]);
  assert.ok(MARKERS.includes("codex-status-writer.js"));
});

run("needsRepair detects missing and stale hooks", () => {
  const desired = desiredHookSettings({
    existing: { hooks: {} },
    nodePath: "/node",
    writerPath: "/new/codex-status-writer.js",
    lifecyclePath: "/new/codex-lifecycle-writer.js",
  });
  assert.equal(needsRepair({ hooks: {} }, desired), true);
  assert.equal(needsRepair(desired, desired), false);
  const stale = JSON.parse(JSON.stringify(desired));
  stale.hooks.UserPromptSubmit[0].hooks[0].command = "\"/node\" \"/old/codex-status-writer.js\" UserPromptSubmit";
  assert.equal(needsRepair(stale, desired), true);
});

run("build copies shared hook lib into app resources", () => {
  const buildScript = fs.readFileSync(path.join(repoRoot, "build.sh"), "utf8");
  assert.ok(buildScript.includes("scripts/lib"));
  assert.ok(buildScript.includes("Contents/Resources/lib"));
});

run("SessionStart hook launches status bar app after writing state", () => {
  const dir = makeTempDir();
  try {
    const appPath = path.join(dir, "CodexStatusBar.app");
    const openLog = path.join(dir, "open.log");
    const openBin = path.join(dir, "open");
    const launchTrace = path.join(dir, "launch.jsonl");
    fs.mkdirSync(appPath, { recursive: true });
    fs.writeFileSync(openBin, `#!/bin/sh\necho "$@" >> "${openLog}"\n`);
    fs.chmodSync(openBin, 0o755);

    const result = cp.spawnSync(process.execPath, [path.join(repoRoot, "scripts", "codex-lifecycle-writer.js"), "SessionStart"], {
      input: JSON.stringify({ session_id: "launch-check", cwd: "/tmp/launch-check", entrypoint: "cli" }),
      encoding: "utf8",
      env: {
        ...process.env,
        CODEX_STATUSBAR_DIR: dir,
        CODEX_STATUSBAR_APP_PATH: appPath,
        CODEX_STATUSBAR_OPEN_BIN: openBin,
        CODEX_STATUSBAR_LAUNCH_TRACE: launchTrace,
        CODEX_STATUSBAR_PROCESS_NAME: "CodexStatusBarNotRunningForTest",
      },
    });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.ok(fs.existsSync(path.join(dir, "state.d", "launch-check.json")));
    assert.ok(fs.existsSync(openLog), fs.existsSync(launchTrace) ? fs.readFileSync(launchTrace, "utf8") : "missing launch trace");
    assert.ok(fs.readFileSync(openLog, "utf8").includes(appPath));
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

run("activity hook launches status bar app after writing state", () => {
  const dir = makeTempDir();
  try {
    const appPath = path.join(dir, "CodexStatusBar.app");
    const openLog = path.join(dir, "open.log");
    const openBin = path.join(dir, "open");
    const launchTrace = path.join(dir, "launch.jsonl");
    fs.mkdirSync(appPath, { recursive: true });
    fs.writeFileSync(openBin, `#!/bin/sh\necho "$@" >> "${openLog}"\n`);
    fs.chmodSync(openBin, 0o755);

    const result = cp.spawnSync(process.execPath, [path.join(repoRoot, "scripts", "codex-status-writer.js"), "UserPromptSubmit"], {
      input: JSON.stringify({ session_id: "activity-launch-check", turn_id: "turn", cwd: "/tmp/activity-launch-check" }),
      encoding: "utf8",
      env: {
        ...process.env,
        CODEX_STATUSBAR_DIR: dir,
        CODEX_STATUSBAR_APP_PATH: appPath,
        CODEX_STATUSBAR_OPEN_BIN: openBin,
        CODEX_STATUSBAR_LAUNCH_TRACE: launchTrace,
        CODEX_STATUSBAR_PROCESS_NAME: "CodexStatusBarNotRunningForTest",
      },
    });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.ok(fs.existsSync(path.join(dir, "state.d", "activity-launch-check.json")));
    assert.ok(fs.existsSync(openLog), fs.existsSync(launchTrace) ? fs.readFileSync(launchTrace, "utf8") : "missing launch trace");
    assert.ok(fs.readFileSync(openLog, "utf8").includes(appPath));
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

run("ensureStatusBarRunning skips open when status bar process already exists", () => {
  const dir = makeTempDir();
  try {
    const appPath = path.join(dir, "CodexStatusBar.app");
    const openLog = path.join(dir, "open.log");
    const openBin = path.join(dir, "open");
    fs.mkdirSync(appPath, { recursive: true });
    fs.writeFileSync(openBin, `#!/bin/sh\necho "$@" >> "${openLog}"\n`);
    fs.chmodSync(openBin, 0o755);

    const { ensureStatusBarRunning } = require("./lib/hook-manager");
    const launched = ensureStatusBarRunning({
      appPath,
      openBin,
      processRunning: () => true,
    });
    assert.equal(launched, false);
    assert.equal(fs.existsSync(openLog), false);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

run("ensureStatusBarRunning ignores same-name process from a different app path", () => {
  const dir = makeTempDir();
  try {
    const appPath = path.join(dir, "Current", "CodexStatusBar.app");
    const otherPath = path.join(dir, "Old", "CodexStatusBar.app", "Contents", "MacOS", "CodexStatusBar");
    const openLog = path.join(dir, "open.log");
    const openBin = path.join(dir, "open");
    fs.mkdirSync(appPath, { recursive: true });
    fs.writeFileSync(openBin, `#!/bin/sh\necho "$@" >> "${openLog}"\n`);
    fs.chmodSync(openBin, 0o755);

    const { ensureStatusBarRunning } = require("./lib/hook-manager");
    const launched = ensureStatusBarRunning({
      appPath,
      openBin,
      processRunning: () => true,
      runningProcessCommands: () => [otherPath],
    });
    assert.equal(launched, true);
    assert.ok(fs.readFileSync(openLog, "utf8").includes(appPath));
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

if (process.exitCode) process.exit(process.exitCode);
