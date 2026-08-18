#!/usr/bin/env node
const assert = require("assert");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

const repoRoot = path.resolve(__dirname, "..");
const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "codex-shortcut-rules-"));
const testPath = path.join(tempDir, "main.swift");
const binaryPath = path.join(tempDir, "verify");

fs.writeFileSync(testPath, String.raw`
import Carbon
import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL \(message)\n", stderr)
        exit(1)
    }
}

expect(GlobalShortcutRules.defaultShortcut.displayText == "\u{2303}\u{2325}Space", "default display")

let custom = GlobalShortcutRules.makeShortcut(
    keyCode: UInt32(kVK_ANSI_K),
    keyLabel: "K",
    control: false,
    option: true,
    shift: true,
    command: true
)
expect(custom?.displayText == "\u{2325}\u{21E7}\u{2318}K", "modifier display order")
expect(GlobalShortcutRules.makeShortcut(
    keyCode: UInt32(kVK_ANSI_K),
    keyLabel: "K",
    control: false,
    option: false,
    shift: false,
    command: false
) == nil, "modifier required")

expect(GlobalShortcutRules.visibilityAction(isRunning: false, isFrontmost: false) == .launch, "launch action")
expect(GlobalShortcutRules.visibilityAction(isRunning: true, isFrontmost: false) == .activate, "activate action")
expect(GlobalShortcutRules.visibilityAction(isRunning: true, isFrontmost: true) == .hide, "hide action")
expect(GlobalShortcutRules.recordingCandidates.contains(where: {
    $0.keyCode == UInt32(kVK_ANSI_K)
        && $0.modifiers == UInt32(controlKey | optionKey)
        && $0.displayText == "\u{2303}\u{2325}K"
}), "recording candidates include control-option letters")

let suite = "codex-statusbar-shortcut-test-\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
expect(GlobalShortcutPreferences.load(defaults: defaults) == GlobalShortcutRules.defaultShortcut, "default preference")
GlobalShortcutPreferences.save(custom, defaults: defaults)
expect(GlobalShortcutPreferences.load(defaults: defaults) == custom, "saved preference")
GlobalShortcutPreferences.save(nil, defaults: defaults)
expect(GlobalShortcutPreferences.load(defaults: defaults) == nil, "disabled preference")

print("PASS global shortcut rules")
`);

try {
  execFileSync("swiftc", [
    path.join(repoRoot, "Sources", "GlobalShortcutRules.swift"),
    testPath,
    "-o", binaryPath,
    "-framework", "Carbon",
  ], { stdio: "inherit" });
  execFileSync(binaryPath, [], { stdio: "inherit" });
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}
