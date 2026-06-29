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
  ["Swift parses focus target", swift.includes("struct FocusTarget") && swift.includes("focusTarget")],
  ["Swift supports process fallback focus", swift.includes("isCodexDesktopProcess")],
  ["Swift supports terminal program mapping", swift.includes("termProgram") && swift.includes("Apple_Terminal")],
  ["Swift supports CLI/APP badges", swift.includes("surfaceTag(") && swift.includes('return "APP"') && swift.includes('return "CLI"')],
  ["Swift performs background startup hook repair", swift.includes("scheduleStartupHookRepair") && swift.includes("DispatchQueue.global")],
  ["Swift can reinstall hooks from app bundle", swift.includes("install-codex-statusbar.js") && swift.includes("runHookInstaller")],
  ["Swift startup hook repair does not persist success signatures", !swift.includes("writeInstallSignature") && !swift.includes("appInstallRecordPath")],
  ["Swift cleans corrupt session files", swift.includes("removeCorruptSessionFile")],
  ["Swift uses pid liveness cleanup", swift.includes("pidAlive") && swift.includes("removeDeadSession")],
  ["Swift supports idle auto exit", swift.includes("autoExitDelay") && swift.includes("evaluateAutoExit")],
  ["Swift avoids high-frequency status item animation", !swift.includes("Timer(timeInterval: 0.12")],
  ["Swift uses standard status item menu binding", swift.includes("statusItem.menu = statusMenu") && !swift.includes("@objc func statusItemClicked")],
  ["Swift keeps image-only status item visible", swift.includes("statusItem.length = NSStatusItem.squareLength") && swift.includes("statusItem.isVisible = true")],
  ["Swift configures status button image scaling", swift.includes("button.imageScaling = .scaleProportionallyDown")],
  ["Swift does not kill duplicate instances on app entry", !swift.includes("terminateDuplicateInstances")],
  ["Swift schedules startup self repair off the launch path", swift.includes("scheduleStartupHookRepair") && swift.includes("DispatchQueue.global")],
  ["Swift auto exit avoids full process-table scans", swift.includes("NSWorkspace.shared.runningApplications") && !swift.includes('process.arguments = ["-axo", "command="]')],
  ["Swift avoids wait-before-read pipe deadlocks", !swift.includes("process.waitUntilExit()\n            let data = pipe.fileHandleForReading.readDataToEndOfFile()")],
  ["Run script avoids forced duplicate open", !fs.readFileSync("script/build_and_run.sh", "utf8").includes("open -g -n")],
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
