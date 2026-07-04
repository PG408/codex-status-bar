#!/usr/bin/env node
const assert = require("assert");
const cp = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const appPath = path.join(repoRoot, "build", "CodexStatusBar.app");
const resourcesPath = path.join(appPath, "Contents", "Resources");
const installerPath = path.join(resourcesPath, "install-codex-statusbar.js");
const statusWriterPath = path.join(resourcesPath, "codex-status-writer.js");
const lifecycleWriterPath = path.join(resourcesPath, "codex-lifecycle-writer.js");
const hookManagerPath = path.join(resourcesPath, "lib", "hook-manager.js");

const runRoot = fs.mkdtempSync(path.join(os.tmpdir(), "codex-statusbar-phase4-"));
const evidenceLog = path.join(runRoot, "phase4-lifecycle.jsonl");

function appendEvidence(event) {
  fs.appendFileSync(evidenceLog, `${JSON.stringify({ ts: new Date().toISOString(), ...event })}\n`);
}

function run(name, fn) {
  try {
    fn();
    appendEvidence({ test: name, ok: true });
    console.log(`PASS ${name}`);
  } catch (error) {
    appendEvidence({
      test: name,
      ok: false,
      error: String(error && error.stack ? error.stack : error),
    });
    console.error(`FAIL ${name}`);
    console.error(error && error.stack ? error.stack : error);
    process.exitCode = 1;
  }
}

function makeTempDir(name) {
  const dir = path.join(runRoot, name);
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function writeJson(file, object) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(object, null, 2)}\n`);
}

function spawnNode(args, options = {}) {
  const result = cp.spawnSync(process.execPath, args, {
    encoding: "utf8",
    ...options,
    env: {
      ...process.env,
      ...(options.env || {}),
    },
  });
  appendEvidence({
    command: [process.execPath, ...args].join(" "),
    status: result.status,
    stdout: result.stdout || "",
    stderr: result.stderr || "",
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  return result;
}

function runBuild() {
  const result = cp.spawnSync("/bin/bash", ["./build.sh"], {
    cwd: repoRoot,
    encoding: "utf8",
  });
  appendEvidence({
    command: "./build.sh",
    status: result.status,
    stdout: result.stdout || "",
    stderr: result.stderr || "",
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
}

function commandPaths(settings) {
  const commands = [];
  for (const groups of Object.values(settings.hooks || {})) {
    for (const group of groups || []) {
      for (const hook of group.hooks || []) {
        commands.push(String(hook.command || ""));
      }
    }
  }
  return commands;
}

function fakeOpenBin(dir) {
  const openLog = path.join(dir, "open.log");
  const openBin = path.join(dir, "open");
  fs.writeFileSync(openBin, `#!/bin/sh\necho "$@" >> "${openLog}"\nexit 0\n`);
  fs.chmodSync(openBin, 0o755);
  return { openBin, openLog };
}

function phaseEnv(dir, extra = {}) {
  const fakeApp = path.join(dir, "CodexStatusBar.app");
  fs.mkdirSync(fakeApp, { recursive: true });
  const { openBin, openLog } = fakeOpenBin(dir);
  return {
    env: {
      CODEX_STATUSBAR_DIR: path.join(dir, "statusbar"),
      CODEX_STATUSBAR_APP_PATH: fakeApp,
      CODEX_STATUSBAR_OPEN_BIN: openBin,
      CODEX_STATUSBAR_LAUNCH_TRACE: path.join(dir, "launch.jsonl"),
      CODEX_STATUSBAR_PROCESS_NAME: "CodexStatusBarNotRunningForPhase4Test",
      ...extra,
    },
    fakeApp,
    openLog,
    launchTrace: path.join(dir, "launch.jsonl"),
    statusDir: path.join(dir, "statusbar"),
  };
}

function assertLaunchLogged(openLog, launchTrace, expectedAppPath) {
  assert.ok(fs.existsSync(openLog), fs.existsSync(launchTrace) ? fs.readFileSync(launchTrace, "utf8") : "missing open log");
  assert.ok(fs.readFileSync(openLog, "utf8").includes(expectedAppPath));
  const trace = fs.readFileSync(launchTrace, "utf8").trim().split("\n").map(JSON.parse);
  assert.ok(trace.some((entry) => entry.ok === true && entry.appPath === expectedAppPath), JSON.stringify(trace));
}

run("build app bundle for packaged lifecycle verification", () => {
  runBuild();
  for (const file of [installerPath, statusWriterPath, lifecycleWriterPath, hookManagerPath]) {
    assert.ok(fs.existsSync(file), `missing packaged resource: ${file}`);
  }
});

run("isolated startup repair installs current hooks and preserves user hooks", () => {
  const home = makeTempDir("home-repair");
  const hooksPath = path.join(home, ".codex", "hooks.json");
  writeJson(hooksPath, {
    hooks: {
      UserPromptSubmit: [
        { hooks: [{ type: "command", command: "\"/old/node\" \"/old/codex-status-writer.js\" UserPromptSubmit" }] },
        { hooks: [{ type: "command", command: "echo keep-user-hook" }] },
      ],
    },
  });

  spawnNode([installerPath], {
    env: {
      HOME: home,
      USERPROFILE: home,
    },
  });

  const repaired = readJson(hooksPath);
  const commands = commandPaths(repaired);
  assert.ok(commands.includes("echo keep-user-hook"));
  assert.ok(commands.some((command) => command.includes("codex-lifecycle-writer.js") && command.includes("SessionStart")));
  assert.ok(commands.some((command) => command.includes("codex-status-writer.js") && command.includes("PreToolUse")));
  assert.ok(!commands.some((command) => command.includes("/old/codex-status-writer.js")));
  assert.ok(fs.existsSync(`${hooksPath}.bak-codex-status-bar`));
});

run("SessionStart writes state and logs hook-launched app open", () => {
  const dir = makeTempDir("session-start-launch");
  const { env, fakeApp, openLog, launchTrace, statusDir } = phaseEnv(dir);
  spawnNode([lifecycleWriterPath, "SessionStart"], {
    input: JSON.stringify({ session_id: "phase4-session-start", cwd: "/tmp/phase4", entrypoint: "cli" }),
    env,
  });
  assert.ok(fs.existsSync(path.join(statusDir, "state.d", "phase4-session-start.json")));
  assertLaunchLogged(openLog, launchTrace, fakeApp);
});

run("activity hook writes state, discovery debug log, and launch trace", () => {
  const dir = makeTempDir("activity-launch");
  const { env, fakeApp, openLog, launchTrace, statusDir } = phaseEnv(dir, {
    CODEX_STATUSBAR_DEBUG: "1",
  });
  spawnNode([statusWriterPath, "UserPromptSubmit"], {
    input: JSON.stringify({ session_id: "phase4-activity", turn_id: "turn-1", cwd: "/tmp/phase4" }),
    env,
  });
  assert.ok(fs.existsSync(path.join(statusDir, "state.d", "phase4-activity.json")));
  assert.ok(fs.existsSync(path.join(statusDir, "hooks-discovery.jsonl")));
  assertLaunchLogged(openLog, launchTrace, fakeApp);
});

run("launcher does not reopen when the same app bundle is already running", () => {
  const dir = makeTempDir("skip-open");
  const fakeApp = path.join(dir, "CodexStatusBar.app");
  const openLog = path.join(dir, "open.log");
  const openBin = path.join(dir, "open");
  fs.mkdirSync(path.join(fakeApp, "Contents", "MacOS"), { recursive: true });
  fs.writeFileSync(openBin, `#!/bin/sh\necho "$@" >> "${openLog}"\nexit 0\n`);
  fs.chmodSync(openBin, 0o755);

  const { ensureStatusBarRunning } = require("./lib/hook-manager");
  const launched = ensureStatusBarRunning({
    appPath: fakeApp,
    openBin,
    runningProcessCommands: () => [path.join(fakeApp, "Contents", "MacOS", "CodexStatusBar")],
  });
  assert.equal(launched, false);
  assert.equal(fs.existsSync(openLog), false);
});

run("Swift liveness, stale cleanup, interrupt, and auto-exit rules pass", () => {
  spawnNode([path.join(repoRoot, "scripts", "verify-swift-state-rules.js")]);
});

run("Swift source contains startup repair, cleanup, and auto-exit lifecycle hooks", () => {
  const swift = fs.readFileSync(path.join(repoRoot, "Sources", "main.swift"), "utf8");
  for (const marker of [
    "scheduleStartupHookRepair",
    "runHookInstaller",
    "cleanupSessionFilesOnStartup",
    "cleanupDeadSessions",
    "removeCorruptSessionFile",
    "evaluateAutoExit",
    "NSApp.terminate",
  ]) {
    assert.ok(swift.includes(marker), `missing Swift lifecycle marker: ${marker}`);
  }
});

console.log(`Phase 4 evidence log: ${evidenceLog}`);

if (process.exitCode) {
  process.exit(process.exitCode);
}
