#!/usr/bin/env node
const fs = require("fs");
const os = require("os");
const path = require("path");

const home = os.homedir();
const repoRoot = path.resolve(__dirname, "..");
const hooksPath = path.join(home, ".codex", "hooks.json");
const markers = [
  "codex-status-writer.js",
  "codex-hook-logger.js",
];
const nodePath = process.execPath;
const bundledWriterPath = path.join(__dirname, "codex-status-writer.js");
const repoWriterPath = path.join(repoRoot, "scripts", "codex-status-writer.js");
const writerPath = fs.existsSync(bundledWriterPath) ? bundledWriterPath : repoWriterPath;

const events = [
  ["SessionStart", ""],
  ["UserPromptSubmit", ""],
  ["PreToolUse", "*"],
  ["PermissionRequest", "*"],
  ["PostToolUse", "*"],
  ["Stop", ""],
  ["SubagentStart", ""],
  ["SubagentStop", ""],
];

function readSettings() {
  if (!fs.existsSync(hooksPath)) return { hooks: {} };
  return JSON.parse(fs.readFileSync(hooksPath, "utf8"));
}

function stripOurs(entries) {
  return (entries || [])
    .map((entry) => ({
      ...entry,
      hooks: (entry.hooks || []).filter((hook) => !markers.some((marker) => (hook.command || "").includes(marker))),
    }))
    .filter((entry) => (entry.hooks || []).length > 0);
}

function addHook(settings, event, matcher) {
  settings.hooks[event] = stripOurs(settings.hooks[event]);
  const command = `"${nodePath}" "${writerPath}" ${event}`;
  const hook = {
    type: "command",
    command,
    timeout: 5,
    statusMessage: `Codex Status Bar: ${event}`,
  };
  const group = matcher ? { matcher, hooks: [hook] } : { hooks: [hook] };
  settings.hooks[event].push(group);
}

function main() {
  if (!fs.existsSync(writerPath)) {
    throw new Error(`Writer not found: ${writerPath}`);
  }

  const settings = readSettings();
  settings.hooks = settings.hooks || {};

  fs.mkdirSync(path.dirname(hooksPath), { recursive: true });
  const backupPath = `${hooksPath}.bak-codex-status-bar`;
  if (fs.existsSync(hooksPath) && !fs.existsSync(backupPath)) {
    fs.copyFileSync(hooksPath, backupPath);
  }

  for (const event of Object.keys(settings.hooks)) {
    settings.hooks[event] = stripOurs(settings.hooks[event]);
    if (settings.hooks[event].length === 0) delete settings.hooks[event];
  }

  for (const [event, matcher] of events) {
    if (!settings.hooks[event]) settings.hooks[event] = [];
    addHook(settings, event, matcher);
  }

  fs.writeFileSync(hooksPath, `${JSON.stringify(settings, null, 2)}\n`);
  console.log(`Installed Codex Status Bar hooks into ${hooksPath}`);
  console.log(`Backup: ${backupPath}`);
  console.log(`State: ${path.join(home, ".codex", "statusbar", "state.json")}`);
}

try {
  main();
} catch (error) {
  console.error(error && error.stack ? error.stack : error);
  process.exit(1);
}
