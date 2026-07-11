#!/usr/bin/env node
const cp = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const source = path.join(repoRoot, "Sources", "PollingRules.swift");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "codex-polling-rules-"));
const verifier = path.join(tmp, "VerifyPollingRules.swift");
const binary = path.join(tmp, "verify-polling-rules");

function assertSourceExists() {
  if (!fs.existsSync(source)) {
    console.error("FAIL PollingRules.swift is missing");
    process.exit(1);
  }
}

try {
  assertSourceExists();
  fs.writeFileSync(verifier, `
import Foundation

func assertBool(_ actual: Bool, _ expected: Bool, _ label: String) {
    if actual != expected {
        fputs("FAIL \\(label): expected \\(expected), got \\(actual)\\n", stderr)
        exit(1)
    }
}

func assertInt(_ actual: Int, _ expected: Int, _ label: String) {
    if actual != expected {
        fputs("FAIL \\(label): expected \\(expected), got \\(actual)\\n", stderr)
        exit(1)
    }
}

@main
struct VerifyPollingRules {
    static func main() {
        let quiet = PollingRules.decision(
            sessionsChanged: false,
            activeTimerSecondChanged: false,
            menuTimerSecondChanged: false,
            maintenanceDue: false,
            menuIsOpen: false
        )
        assertBool(quiet.shouldEvaluate, false, "quiet tick skips evaluation")
        assertBool(quiet.shouldRefreshMetadata, false, "quiet tick skips metadata")
        assertBool(quiet.shouldRefreshMenu, false, "quiet tick skips menu refresh")
        assertBool(quiet.shouldRunMaintenance, false, "quiet tick skips maintenance")

        let sessionChange = PollingRules.decision(
            sessionsChanged: true,
            activeTimerSecondChanged: false,
            menuTimerSecondChanged: false,
            maintenanceDue: false,
            menuIsOpen: true
        )
        assertBool(sessionChange.shouldEvaluate, true, "session change evaluates immediately")
        assertBool(sessionChange.shouldRefreshMetadata, true, "session change refreshes metadata")
        assertBool(sessionChange.shouldRefreshMenu, true, "session change refreshes open menu")
        assertBool(sessionChange.shouldRunMaintenance, false, "session change does not force maintenance")

        let timerChange = PollingRules.decision(
            sessionsChanged: false,
            activeTimerSecondChanged: true,
            menuTimerSecondChanged: false,
            maintenanceDue: false,
            menuIsOpen: false
        )
        assertBool(timerChange.shouldEvaluate, true, "active timer evaluates once per second")
        assertBool(timerChange.shouldRefreshMetadata, false, "timer does not refresh metadata")

        let menuTimer = PollingRules.decision(
            sessionsChanged: false,
            activeTimerSecondChanged: false,
            menuTimerSecondChanged: true,
            maintenanceDue: false,
            menuIsOpen: true
        )
        assertBool(menuTimer.shouldEvaluate, false, "menu-only timer does not evaluate lead session")
        assertBool(menuTimer.shouldRefreshMenu, true, "menu timer refreshes open rows")

        let closedMenuTimer = PollingRules.decision(
            sessionsChanged: false,
            activeTimerSecondChanged: false,
            menuTimerSecondChanged: true,
            maintenanceDue: false,
            menuIsOpen: false
        )
        assertBool(closedMenuTimer.shouldRefreshMenu, false, "closed menu ignores menu timer")

        let maintenance = PollingRules.decision(
            sessionsChanged: false,
            activeTimerSecondChanged: false,
            menuTimerSecondChanged: false,
            maintenanceDue: true,
            menuIsOpen: true
        )
        assertBool(maintenance.shouldEvaluate, true, "maintenance reevaluates session liveness")
        assertBool(maintenance.shouldRefreshMetadata, true, "maintenance refreshes metadata")
        assertBool(maintenance.shouldRefreshMenu, true, "maintenance refreshes open menu")
        assertBool(maintenance.shouldRunMaintenance, true, "maintenance runs cleanup and auto exit")

        assertBool(PollingRules.secondChanged(current: nil, previous: nil), false, "missing timers remain quiet")
        assertBool(PollingRules.secondChanged(current: 12, previous: 12), false, "same second remains quiet")
        assertBool(PollingRules.secondChanged(current: 13, previous: 12), true, "new second is observed")
        assertBool(PollingRules.maintenanceIsDue(now: 100, previous: nil, interval: 5), true, "first tick performs maintenance")
        assertBool(PollingRules.maintenanceIsDue(now: 104, previous: 100, interval: 5), false, "maintenance waits for interval")
        assertBool(PollingRules.maintenanceIsDue(now: 105, previous: 100, interval: 5), true, "maintenance runs at interval")

        var cache = TimedBooleanCache()
        var loads = 0
        func load() -> Bool {
            loads += 1
            return loads.isMultiple(of: 2)
        }

        assertBool(cache.resolve(now: 100, ttl: 5, loader: load), false, "cache performs initial load")
        assertBool(cache.resolve(now: 104.9, ttl: 5, loader: load), false, "cache reuses value within ttl")
        assertInt(loads, 1, "cache invokes loader once within ttl")
        assertBool(cache.resolve(now: 105, ttl: 5, loader: load), true, "cache refreshes at ttl")
        assertInt(loads, 2, "cache invokes loader after ttl")

        print("PASS polling rules")
    }
}
`);

  cp.execFileSync("/usr/bin/swiftc", [source, verifier, "-o", binary], {
    stdio: "inherit",
  });
  cp.execFileSync(binary, [], { stdio: "inherit" });
} finally {
  fs.rmSync(tmp, { recursive: true, force: true });
}
