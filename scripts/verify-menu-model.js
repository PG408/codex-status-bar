#!/usr/bin/env node
const fs = require("fs");

const swift = fs.readFileSync("Sources/main.swift", "utf8");
const readme = fs.readFileSync("README.md", "utf8");
const docs = fs.existsSync("docs/sessions-menu.md")
  ? fs.readFileSync("docs/sessions-menu.md", "utf8")
  : "";

const checks = [
  ["Swift defines SessionRowView", swift.includes("final class SessionRowView")],
  ["Swift has Sessions menu section", swift.includes('header("Sessions")')],
  ["Swift has Options menu section", swift.includes('header("Options")')],
  ["Swift has Icon menu section", swift.includes('header("Icon")')],
  ["Swift has Diagnostics menu section", swift.includes('header("Diagnostics")')],
  ["Swift stores open menu session rows", swift.includes("sessionMenuItems")],
  ["Swift refreshes open menu rows", swift.includes("refreshOpenMenuRows")],
  ["Swift supports Hide idle sessions", swift.includes("Hide idle sessions") && swift.includes("hideIdleAfter")],
  ["Swift supports session click focus", swift.includes("openSession(") && swift.includes("openCodex")],
  ["Swift supports terminal program mapping", swift.includes("termProgram") && swift.includes("Apple_Terminal")],
  ["Swift supports CLI/APP badges", swift.includes("surfaceTag(") && swift.includes('return "APP"') && swift.includes('return "CLI"')],
  ["Docs mention Sessions menu", readme.includes("Sessions Menu") || docs.includes("Sessions Menu")],
  ["Docs mention hide idle behavior", readme.includes("Hide idle sessions") || docs.includes("Hide idle sessions")],
  ["Docs mention click focus boundary", readme.includes("click") || docs.includes("click")],
];

const failed = checks.filter(([, ok]) => !ok);
for (const [name, ok] of checks) {
  console.log(`${ok ? "PASS" : "FAIL"} ${name}`);
}

if (failed.length > 0) {
  process.exit(1);
}
