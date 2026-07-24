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

function makeAppBundle(appPath, processName = "CodexStatusBar") {
  const executablePath = path.join(appPath, "Contents", "MacOS", processName);
  fs.mkdirSync(path.dirname(executablePath), { recursive: true });
  fs.writeFileSync(executablePath, "");
  fs.chmodSync(executablePath, 0o755);
  fs.writeFileSync(path.join(appPath, "Contents", "Info.plist"), "<plist><dict/></plist>");
  return executablePath;
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

run("resolveScriptPaths prefers explicit app path resources", () => {
  const root = makeTempDir();
  try {
    const repoResources = path.join(root, "repo", "scripts");
    const appResources = path.join(root, "CodexStatusBar.app", "Contents", "Resources");
    fs.mkdirSync(repoResources, { recursive: true });
    fs.mkdirSync(appResources, { recursive: true });
    fs.writeFileSync(path.join(repoResources, "codex-status-writer.js"), "");
    fs.writeFileSync(path.join(appResources, "codex-status-writer.js"), "");
    fs.writeFileSync(path.join(appResources, "codex-lifecycle-writer.js"), "");
    fs.writeFileSync(path.join(appResources, "install-codex-statusbar.js"), "");

    const paths = resolveScriptPaths({
      scriptDir: repoResources,
      repoRoot: path.join(root, "repo"),
      appPath: path.join(root, "CodexStatusBar.app"),
    });
    assert.equal(paths.writerPath, path.join(appResources, "codex-status-writer.js"));
    assert.equal(paths.lifecyclePath, path.join(appResources, "codex-lifecycle-writer.js"));
    assert.equal(paths.installPath, path.join(appResources, "install-codex-statusbar.js"));
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
    appPath: "/Applications/CodexStatusBar.app",
  });
  for (const spec of EVENT_SPECS) {
    assert.ok(settings.hooks[spec.event], `missing ${spec.event}`);
  }
  const commands = commandPaths(settings);
  assert.ok(commands.some((command) => command.includes("codex-lifecycle-writer.js") && command.includes("SessionStart")));
  assert.ok(commands.some((command) => command.includes("codex-status-writer.js") && command.includes("PreToolUse")));
  assert.ok(commands.some((command) => command.includes("codex-status-writer.js") && command.includes("PreCompact")));
  assert.ok(commands.some((command) => command.includes("codex-status-writer.js") && command.includes("PostCompact")));
  assert.ok(commands.every((command) => command.includes("--app-path") && command.includes("/Applications/CodexStatusBar.app")));
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
    appPath: "/Applications/CodexStatusBar.app",
  });
  const commands = commandPaths(repaired);
  assert.ok(commands.includes("echo user-hook"));
  assert.ok(commands.some((command) => command.includes("\"/new/node\"") && command.includes("/new/codex-status-writer.js")));
  assert.ok(commands.some((command) => command.includes("--app-path") && command.includes("/Applications/CodexStatusBar.app")));
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
    makeAppBundle(appPath, "CodexStatusBarNotRunningForTest");
    fs.writeFileSync(openBin, `#!/bin/sh\necho "$@" >> "${openLog}"\n`);
    fs.chmodSync(openBin, 0o755);

    const result = cp.spawnSync(process.execPath, [path.join(repoRoot, "scripts", "codex-lifecycle-writer.js"), "SessionStart"], {
      input: JSON.stringify({
        session_id: "launch-check",
        cwd: "/tmp/launch-check",
        entrypoint: "cli",
        transcript_path: "/tmp/launch-check/session.jsonl",
      }),
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
    makeAppBundle(appPath, "CodexStatusBarNotRunningForTest");
    fs.writeFileSync(openBin, `#!/bin/sh\necho "$@" >> "${openLog}"\n`);
    fs.chmodSync(openBin, 0o755);

    const result = cp.spawnSync(process.execPath, [path.join(repoRoot, "scripts", "codex-status-writer.js"), "UserPromptSubmit"], {
      input: JSON.stringify({
        session_id: "activity-launch-check",
        turn_id: "turn",
        cwd: "/tmp/activity-launch-check",
        transcript_path: "/tmp/activity-launch-check/session.jsonl",
      }),
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

run("ensureStatusBarRunning skips open when the target executable is running", () => {
  const dir = makeTempDir();
  try {
    const appPath = path.join(dir, "CodexStatusBar.app");
    const executablePath = makeAppBundle(appPath);
    const openLog = path.join(dir, "open.log");
    const openBin = path.join(dir, "open");
    fs.writeFileSync(openBin, `#!/bin/sh\necho "$@" >> "${openLog}"\n`);
    fs.chmodSync(openBin, 0o755);

    const { ensureStatusBarRunning } = require("./lib/hook-manager");
    const launched = ensureStatusBarRunning({
      appPath,
      openBin,
      runningProcessCommands: () => [executablePath],
    });
    assert.equal(launched, false);
    assert.equal(fs.existsSync(openLog), false);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

run("ensureStatusBarRunning opens when only a different bundle executable is running", () => {
  const dir = makeTempDir();
  try {
    const appPath = path.join(dir, "Current", "CodexStatusBar.app");
    const otherPath = path.join(dir, "Old", "CodexStatusBar.app", "Contents", "MacOS", "CodexStatusBar");
    const openLog = path.join(dir, "open.log");
    const openBin = path.join(dir, "open");
    makeAppBundle(appPath);
    makeAppBundle(path.join(dir, "Old", "CodexStatusBar.app"));
    fs.writeFileSync(openBin, `#!/bin/sh\necho "$@" >> "${openLog}"\n`);
    fs.chmodSync(openBin, 0o755);

    const { ensureStatusBarRunning } = require("./lib/hook-manager");
    const launched = ensureStatusBarRunning({
      appPath,
      openBin,
      runningProcessCommands: () => [otherPath],
    });
    assert.equal(launched, true);
    assert.ok(fs.readFileSync(openLog, "utf8").includes(appPath));
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

run("ensureStatusBarRunning does not confuse a path prefix with the target", () => {
  const dir = makeTempDir();
  try {
    const appPath = path.join(dir, "CodexStatusBar.app");
    const similarAppPath = path.join(dir, "CodexStatusBar.app.backup");
    const similarExecutable = makeAppBundle(similarAppPath);
    const openLog = path.join(dir, "open.log");
    const openBin = path.join(dir, "open");
    makeAppBundle(appPath);
    fs.writeFileSync(openBin, `#!/bin/sh\necho "$@" >> "${openLog}"\n`);
    fs.chmodSync(openBin, 0o755);

    const { ensureStatusBarRunning } = require("./lib/hook-manager");
    const launched = ensureStatusBarRunning({
      appPath,
      openBin,
      runningProcessCommands: () => [similarExecutable],
    });
    assert.equal(launched, true);
    assert.ok(fs.readFileSync(openLog, "utf8").includes(appPath));
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

run("ensureStatusBarRunning matches canonical executable paths through a symlink", () => {
  const dir = makeTempDir();
  try {
    const realAppPath = path.join(dir, "Versioned", "CodexStatusBar.app");
    const linkedAppPath = path.join(dir, "Current", "CodexStatusBar.app");
    const executablePath = makeAppBundle(realAppPath);
    fs.mkdirSync(path.dirname(linkedAppPath), { recursive: true });
    fs.symlinkSync(realAppPath, linkedAppPath);

    const { ensureStatusBarRunning } = require("./lib/hook-manager");
    const launched = ensureStatusBarRunning({
      appPath: linkedAppPath,
      runningProcessCommands: () => [executablePath],
    });
    assert.equal(launched, false);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

run("ensureStatusBarRunning matches an executable path containing spaces", () => {
  const dir = makeTempDir();
  try {
    const appPath = path.join(dir, "Current Build", "Codex Status Bar.app");
    const executablePath = makeAppBundle(appPath);

    const { ensureStatusBarRunning } = require("./lib/hook-manager");
    const launched = ensureStatusBarRunning({
      appPath,
      runningProcessCommands: () => [executablePath],
    });
    assert.equal(launched, false);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

run("ensureStatusBarRunning respects a configured process name", () => {
  const dir = makeTempDir();
  try {
    const appPath = path.join(dir, "CodexStatusBarTest.app");
    const processName = "CodexStatusBarTest";
    const executablePath = makeAppBundle(appPath, processName);

    const { ensureStatusBarRunning } = require("./lib/hook-manager");
    const launched = ensureStatusBarRunning({
      appPath,
      processName,
      runningProcessCommands: () => [executablePath],
    });
    assert.equal(launched, false);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

run("ensureStatusBarRunning validates the app path before checking processes", () => {
  const dir = makeTempDir();
  try {
    let processCheckCalled = false;
    const { ensureStatusBarRunning } = require("./lib/hook-manager");
    const launched = ensureStatusBarRunning({
      appPath: path.join(dir, "Missing", "CodexStatusBar.app"),
      runningProcessCommands: () => {
        processCheckCalled = true;
        return [];
      },
    });
    assert.equal(launched, false);
    assert.equal(processCheckCalled, false);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

run("ensureStatusBarRunning rejects an incomplete app bundle", () => {
  const dir = makeTempDir();
  try {
    const appPath = path.join(dir, "Incomplete", "CodexStatusBar.app");
    fs.mkdirSync(appPath, { recursive: true });
    let processCheckCalled = false;
    const { ensureStatusBarRunning } = require("./lib/hook-manager");
    const launched = ensureStatusBarRunning({
      appPath,
      runningProcessCommands: () => {
        processCheckCalled = true;
        return [];
      },
    });
    assert.equal(launched, false);
    assert.equal(processCheckCalled, false);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

if (process.exitCode) process.exit(process.exitCode);
