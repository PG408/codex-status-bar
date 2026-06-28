#!/usr/bin/env node
const fs = require("fs");
const os = require("os");
const path = require("path");

const hooksPath = path.join(os.homedir(), ".codex", "hooks.json");
const markers = [
  "codex-status-writer.js",
  "codex-hook-logger.js",
];

if (!fs.existsSync(hooksPath)) {
  console.log(`No hooks file at ${hooksPath}`);
  process.exit(0);
}

const settings = JSON.parse(fs.readFileSync(hooksPath, "utf8"));
for (const event of Object.keys(settings.hooks || {})) {
  settings.hooks[event] = (settings.hooks[event] || [])
    .map((entry) => ({
      ...entry,
      hooks: (entry.hooks || []).filter((hook) => !markers.some((marker) => (hook.command || "").includes(marker))),
    }))
    .filter((entry) => (entry.hooks || []).length > 0);
  if (settings.hooks[event].length === 0) delete settings.hooks[event];
}
fs.writeFileSync(hooksPath, `${JSON.stringify(settings, null, 2)}\n`);
console.log(`Removed Codex Status Bar hooks from ${hooksPath}`);
