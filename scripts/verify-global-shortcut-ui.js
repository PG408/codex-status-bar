#!/usr/bin/env node
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

const repoRoot = path.resolve(__dirname, "..");
const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "codex-shortcut-ui-"));
const testPath = path.join(tempDir, "main.swift");
const binaryPath = path.join(tempDir, "verify");

fs.writeFileSync(testPath, String.raw`
import Carbon
import Cocoa

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL \(message)\n", stderr)
        exit(1)
    }
}

let registrar = ShortcutRecordingHotKeyRegistrar()
var captured: GlobalShortcutDefinition?
registrar.onAction = { action in
    if case let .capture(shortcut) = action {
        captured = shortcut
    }
}
expect(registrar.start(), "recording hot keys register")

var event: EventRef?
expect(CreateEvent(
    nil,
    OSType(kEventClassKeyboard),
    UInt32(kEventHotKeyPressed),
    GetCurrentEventTime(),
    0,
    &event
) == noErr, "raw keyboard event creates")
guard let event else { exit(1) }
defer { ReleaseEvent(event) }

var identifier = EventHotKeyID(
    signature: OSType(0x43445852),
    id: ShortcutRecordingHotKeyRegistrar.firstShortcutIdentifier
)
expect(SetEventParameter(
    event,
    OSType(kEventParamDirectObject),
    OSType(typeEventHotKeyID),
    MemoryLayout<EventHotKeyID>.size,
    &identifier
) == noErr, "hot key identifier attaches")

expect(SendEventToEventTarget(event, GetApplicationEventTarget()) == noErr, "hot key event dispatches")
RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
expect(captured == GlobalShortcutRules.recordingCandidates.first, "shortcut captured")
registrar.stop()

print("PASS global shortcut UI event capture")
`);

try {
  execFileSync("swiftc", [
    path.join(repoRoot, "Sources", "GlobalShortcutRules.swift"),
    path.join(repoRoot, "Sources", "GlobalShortcutUI.swift"),
    testPath,
    "-o", binaryPath,
    "-framework", "Cocoa",
    "-framework", "Carbon",
  ], { stdio: "inherit" });
  execFileSync(binaryPath, [], { stdio: "inherit" });
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}
