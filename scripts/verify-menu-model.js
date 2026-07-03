#!/usr/bin/env node
const fs = require("fs");
const path = require("path");

const swift = fs
  .readdirSync("Sources")
  .filter((file) => file.endsWith(".swift"))
  .map((file) => fs.readFileSync(path.join("Sources", file), "utf8"))
  .join("\n");
const readme = fs.readFileSync("README.md", "utf8");
const docs = fs.existsSync("docs/sessions-menu.md")
  ? fs.readFileSync("docs/sessions-menu.md", "utf8")
  : "";
const writer = fs.readFileSync("scripts/codex-status-writer.js", "utf8");

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
  ["Swift supports URL focus target fallback", swift.includes('case "url"') && swift.includes("openURLTarget") && swift.includes("openFallbackTarget")],
  ["Swift derives Codex thread deeplink target", swift.includes("codex://threads/") && swift.includes("desktopThreadTarget")],
  ["Swift parses focus target", swift.includes("struct FocusTarget") && swift.includes("focusTarget")],
  ["Swift supports process fallback focus", swift.includes("isCodexDesktopProcess")],
  ["Swift supports terminal program mapping", swift.includes("termProgram") && swift.includes("Apple_Terminal")],
  ["Swift supports CLI/APP badges", swift.includes("surfaceTag(") && swift.includes('return "APP"') && swift.includes('return "CLI"')],
  ["Swift supports compacting state", swift.includes("case compacting") && swift.includes('"Compacting"')],
  ["Swift performs background startup hook repair", swift.includes("scheduleStartupHookRepair") && swift.includes("DispatchQueue.global")],
  ["Swift can reinstall hooks from app bundle", swift.includes("install-codex-statusbar.js") && swift.includes("runHookInstaller")],
  ["Swift startup hook repair does not persist success signatures", !swift.includes("writeInstallSignature") && !swift.includes("appInstallRecordPath")],
  ["Swift cleans corrupt session files", swift.includes("removeCorruptSessionFile")],
  ["Swift uses pid liveness cleanup", swift.includes("pidAlive") && swift.includes("removeDeadSession")],
  ["Swift supports idle auto exit", swift.includes("autoExitDelay") && swift.includes("evaluateAutoExit")],
  ["Swift does not age live thinking into idle by quiet timeout", !swift.includes("quietThinkingAfter") && !swift.includes("quietAge")],
  ["Swift keeps tool active until PostToolUse instead of visible timeout downgrade", !swift.includes("state == .tool, session.visibleUntilMs > 0")],
  ["Swift does not introduce a long-running tool state", !swift.includes("case toolLongRunning") && !swift.includes("\"toolLongRunning\"")],
  ["Swift derives long-running tool icon warning without changing label", swift.includes("isLongRunningTool") && swift.includes("longRunningToolIconTint")],
  ["Swift has surface-aware desktop liveness", swift.includes("isDesktopSession(") && swift.includes("codexDesktopProcessExists()")],
  ["Swift does not use desktop pid as session liveness", swift.includes("!isDesktopSession(session) && session.pid > 0")],
  ["Swift uses Codex process fallback consistently for desktop liveness", swift.includes("func isDesktopSession") && swift.includes("return isCodexDesktopProcess(pid: session.pid)")],
  ["Swift treats compacting and tools as active priority", swift.includes("case .thinking, .tool, .compacting")],
  ["Writer preserves existing tool timer semantics", writer.includes("if (!startedAt) startedAt = now") && writer.includes("if (!startedAt) startedAt = afterWaitNow")],
  ["Writer preserves transcript path for interrupt recovery", writer.includes("transcript_path") && writer.includes("prev.transcript")],
  ["Swift uses transcript turn_aborted marker for active-state recovery", swift.includes("transcriptShowsUserInterrupt") && swift.includes("turn_aborted")],
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
  ["Docs mention Desktop thread deeplink", docs.includes("codex://threads/<sessionId>")],
];

const failed = checks.filter(([, ok]) => !ok);
for (const [name, ok] of checks) {
  console.log(`${ok ? "PASS" : "FAIL"} ${name}`);
}

if (failed.length > 0) {
  process.exit(1);
}
