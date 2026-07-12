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
const lifecycleWriter = fs.readFileSync("scripts/codex-lifecycle-writer.js", "utf8");
const buildScript = fs.readFileSync("build.sh", "utf8");
const runScript = fs.readFileSync("script/build_and_run.sh", "utf8");
const visualStatusDocs = fs.readFileSync("docs/visual-status.md", "utf8");

const checks = [
  ["Swift defines SessionRowView", swift.includes("final class SessionRowView")],
  ["Swift vertically centers session row text", swift.includes("private var textY: CGFloat { (rowH - textH) / 2 }") && swift.includes("height: textH")],
  ["Swift has Sessions menu section", swift.includes('header("Sessions")')],
  ["Swift has Options menu section", swift.includes('header("Options")')],
  ["Swift has Icon menu section", swift.includes('header("Icon")')],
  ["Swift has Diagnostics menu section", swift.includes('header("Diagnostics")')],
  ["Swift displays the bundle version in Diagnostics", swift.includes('title: "Version \\(appVersion)"') && swift.includes('forInfoDictionaryKey: "CFBundleShortVersionString"') && swift.includes("versionItem.isEnabled = false")],
  ["Swift stores open menu session rows", swift.includes("sessionMenuItems")],
  ["Swift refreshes open menu rows", swift.includes("refreshOpenMenuRows")],
  ["Swift groups session menu rows by project", swift.includes("SessionGroupHeaderView") && swift.includes("groupedMenuSessions") && swift.includes("sessionGroupName")],
  ["Swift displays thread names in session rows", swift.includes("threadName") && swift.includes("defaultThreadName") && swift.includes("session.threadName")],
  ["Swift lets session row width drive thread name truncation", swift.includes("lineBreakMode = .byTruncatingTail") && swift.includes("row.configure(name: sessionName(for: session)") && swift.includes("maxNameW") && !swift.includes("truncated(sessionName(for: session)")],
  ["Swift reads Codex thread metadata overlay", swift.includes("ThreadMetadataStore") && swift.includes("refreshThreadMetadata")],
  ["Swift hides archived threads from lead and menu", swift.includes("isArchivedThread") && swift.includes("displaySessions") && swift.includes("filter { !isArchivedThread($0) }")],
  ["Swift settles archived active sessions to done", swift.includes("applyArchivedThreadOverlay") && swift.includes("markArchivedSessionDone")],
  ["Swift supports Hide idle sessions", swift.includes("Hide idle sessions") && swift.includes("hideIdleAfter")],
  ["Swift supports idle visibility through seven days", swift.includes('(\"12 hours\", 12 * 3600.0)') && swift.includes('(\"24 hours\", 24 * 3600.0)') && swift.includes('(\"7 days\", SessionStateRules.sessionRetentionAfter)') && !swift.includes('(\"Never\", 0.0)')],
  ["Swift separates menu visibility from seven-day state retention", swift.includes("SessionStateRules.shouldHideSession(") && swift.includes("SessionStateRules.sessionRetentionAfter") && swift.includes("func cleanupDeadSessions()") && !swift.includes("restingSessionPruneAfter: hideIdleAfter")],
  ["Swift does not force an expired session into an empty menu", !swift.includes("if filtered.isEmpty") && !swift.includes("return [fallback]")],
  ["Swift hides resting Side Chat rows after five minutes without deleting state", swift.includes("sideChatRestingMenuHideAfter") && swift.includes("5 * 60") && swift.includes("isHiddenSideChatMenuSession") && swift.includes('== "Side Chat"')],
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
  ["Swift uses pid liveness for effective state without immediate cleanup", swift.includes("pidAlive") && swift.includes("effectiveState(for session") && !swift.includes("pidAlive: livePid")],
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
  ["Writer uses Thinking label consistently", writer.includes('"Thinking"') && !writer.includes('"Thinking..."') && !writer.includes('"Codex thinking"')],
  ["Writer keeps unknown tool fallback at event layer", writer.includes('labelForTool(toolName) || "Using tool"') && !writer.includes('return labels[toolName] || "Using tool"')],
  ["Writer derives display fields from single-session status facts", writer.includes("function deriveVisibleState") && writer.includes("statusFacts: facts")],
  ["Writer keeps subagent activity to two Subagent labels", writer.includes('"Subagent"') && writer.includes('"Subagent permission"') && !writer.includes('"Subagent running"') && !writer.includes('"Subagent awaiting permission"')],
  ["Writer recognizes subagent payload ownership", writer.includes("function isSubagentPayload") && writer.includes("payload.agent_id || payload.agent_type")],
  ["Writer does not treat SubagentStop as session Stop", writer.includes('case "SubagentStop"') && writer.includes("stopSubagent(facts, payload)") && !writer.includes('case "Stop":\n    case "SubagentStop"')],
  ["Writers persist session_index thread names", writer.includes("latestThreadName(sessionId)") && lifecycleWriter.includes("latestThreadName(sessionId)")],
  ["Session index resolver labels Side Chat sessions", fs.readFileSync("scripts/lib/session-index.js", "utf8").includes('"Side Chat"') && fs.readFileSync("scripts/lib/session-index.js", "utf8").includes("hasSideChatPromptHistory")],
  ["Writer preserves transcript path for interrupt recovery", writer.includes("transcript_path") && writer.includes("prev.transcript")],
  ["Swift uses transcript terminal events for active-state recovery", swift.includes("transcriptTerminalState") && swift.includes("TranscriptStateRules.terminalState")],
  ["Swift avoids high-frequency status item animation", !swift.includes("Timer(timeInterval: 0.12")],
  ["Swift keeps the 0.4 second polling interval", swift.includes("let pollInterval: TimeInterval = 0.4")],
  ["Swift gates tick work through pure polling rules", swift.includes("PollingRules.decision(") && swift.includes("let sessionsChanged = reloadSessions()")],
  ["Swift limits maintenance work to five second intervals", swift.includes("let maintenanceInterval: TimeInterval = 5") && swift.includes("PollingRules.maintenanceIsDue(")],
  ["Swift caches Codex Desktop detection", swift.includes("TimedBooleanCache") && swift.includes("var cache = codexDesktopProcessCache") && swift.includes("cache.resolve(") && swift.includes("codexDesktopProcessCache = cache")],
  ["Swift caches process-based desktop session inference", swift.includes("desktopSessionProcessCaches") && swift.includes("desktopSessionProcessCaches[pid]") && swift.includes("cache.resolve(")],
  ["Swift passes one Codex liveness snapshot through evaluation", swift.includes("func evaluate(codexRunning: Bool)") && swift.includes("func cleanupDeadSessions()") && swift.includes("func evaluateAutoExit(codexRunning: Bool)")],
  ["Swift refreshes open menu rows at most once per wall second", swift.includes("menuTimerSecondChanged") && swift.includes("lastObservedMenuSecond")],
  ["Swift uses standard status item menu binding", swift.includes("statusItem.menu = statusMenu") && !swift.includes("@objc func statusItemClicked")],
  ["Swift assigns a stable unique status item identity", swift.includes('statusItem.autosaveName = "io.github.pg408.codexstatusbar.status-item"')],
  ["Swift keeps image-only status item visible", swift.includes("statusItem.length = NSStatusItem.squareLength") && swift.includes("statusItem.isVisible = true")],
  ["Swift sizes the active status item from displayed content", swift.includes("statusTitleLayout(label: label, timer: displayedTimer)") && swift.includes("statusItem.length = layout.itemWidth") && !swift.includes("statusItem.length = NSStatusItem.variableLength")],
  ["Swift measures the current status text and timer", swift.includes("measuredTextWidth(label)") && swift.includes("measuredTextWidth(timer)") && swift.includes("statusTimerSafetyPadding")],
  ["Swift keeps a six-point text-to-timer gap", swift.includes("let statusTextTimerGap: CGFloat = 6")],
  ["Swift removes grouped status width reservations", !swift.includes("statusWidthGroupLabels") && !swift.includes("measuredMaxStatusTextWidth") && !swift.includes("timerWidthSampleSeconds")],
  ["Swift renders active status through one rasterized image", swift.includes("StatusItemBitmapRenderer") && swift.includes("statusBitmapRenderer.image(") && swift.includes("button.imagePosition = .imageOnly")],
  ["Swift does not attach custom views to the status button", !swift.includes("statusIconView") && !swift.includes("statusTextField") && !swift.includes("statusTimerField") && !swift.includes("installStatusSubviews(in: button)")],
  ["Bitmap renderer left-aligns status text and right-aligns timer", swift.includes("alignment: .left") && swift.includes("alignment: .right") && swift.includes("content.labelRect") && swift.includes("content.timerRect")],
  ["Swift exposes active status through accessibility", swift.includes("setAccessibilityLabel") && swift.includes("setAccessibilityValue")],
  ["Swift rasterizes status text in the menu bar appearance", swift.includes("button.effectiveAppearance.performAsCurrentDrawingAppearance")],
  ["Swift refreshes the initial bitmap after status item registration", swift.includes("scheduleInitialStatusAppearanceRefresh") && swift.includes("DispatchQueue.main.async")],
  ["Swift collapses inactive status item to icon only", swift.includes("guard activeState != .idle && activeState != .done else") && swift.includes("button.imagePosition = .imageOnly")],
  ["Swift does not collapse active timer layout just because timer text is empty", swift.includes("if !showStatusText && !showTimer") && !swift.includes("!showStatusText && (!showTimer || timer.isEmpty)")],
  ["Swift configures status button image scaling", swift.includes("button.imageScaling = .scaleProportionallyDown")],
  ["Codex template source assets are present", fs.existsSync("assets/status-icons/codexTemplate.png") && fs.existsSync("assets/status-icons/codexTemplate@2x.png")],
  ["Build copies bundled Codex template assets", buildScript.includes('cp assets/status-icons/codexTemplate.png "$APP/Contents/Resources/codexTemplate.png"') && buildScript.includes('cp assets/status-icons/codexTemplate@2x.png "$APP/Contents/Resources/codexTemplate@2x.png"')],
  ["Swift loads the bundled Codex template before its drawing fallback", swift.includes("bundledCodexTemplateIcon") && swift.includes("loadBundledCodexTemplateIcon") && swift.includes('codexTemplate@2x.png') && swift.includes("tintedAppIcon(source: templateIcon, color: color") && !swift.includes("loadInstalledCodexIcon") && !swift.includes("loadInstalledCodexTemplateIcon")],
  ["System icon color option is fully removed", !swift.includes("iconSystem") && !swift.includes("Use system icon color") && !swift.includes("toggleIconColor") && !readme.includes("Use system icon color") && !visualStatusDocs.includes("Use system icon color")],
  ["Swift does not kill duplicate instances on app entry", !swift.includes("terminateDuplicateInstances")],
  ["Swift schedules startup self repair off the launch path", swift.includes("scheduleStartupHookRepair") && swift.includes("DispatchQueue.global")],
  ["Swift auto exit avoids full process-table scans", swift.includes("NSWorkspace.shared.runningApplications") && !swift.includes('process.arguments = ["-axo", "command="]')],
  ["Swift avoids wait-before-read pipe deadlocks", !swift.includes("process.waitUntilExit()\n            let data = pipe.fileHandleForReading.readDataToEndOfFile()")],
  ["Run script avoids forced duplicate open", !fs.readFileSync("script/build_and_run.sh", "utf8").includes("open -g -n")],
  ["Build and run scripts use the stable bundle identifier", buildScript.includes("io.github.pg408.codexstatusbar") && runScript.includes('BUNDLE_ID="io.github.pg408.codexstatusbar"') && !buildScript.includes("com.local.codexstatusbar") && !runScript.includes("com.local.codexstatusbar")],
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
