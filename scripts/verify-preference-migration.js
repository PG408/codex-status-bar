#!/usr/bin/env node
const assert = require("assert");
const cp = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const rulesPath = path.join(repoRoot, "Sources", "PreferenceMigrationRules.swift");
const mainPath = path.join(repoRoot, "Sources", "main.swift");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "codex-statusbar-preferences-"));
const verifierPath = path.join(tmp, "VerifyPreferenceMigration.swift");
const binaryPath = path.join(tmp, "verify-preference-migration");

function verifySourceWiring() {
  const main = fs.readFileSync(mainPath, "utf8");
  const autosaveLiteral = "main-status-item-v1";
  assert.equal((main.match(new RegExp(autosaveLiteral, "g")) || []).length, 1);
  assert.ok(main.includes("private static let mainStatusItemAutosaveName"));
  assert.ok(!main.includes("io.github.pg408.codexstatusbar.status-item"));

  const assignment = main.indexOf("statusItem.autosaveName = Self.mainStatusItemAutosaveName");
  const menuBinding = main.indexOf("statusItem.menu = statusMenu");
  const visibleAssignment = main.indexOf("statusItem.isVisible = true");
  const migration = main.indexOf("LegacyPreferenceMigrator.migrateIfNeeded()", assignment);
  const defaultsRead = main.indexOf("let defaults = UserDefaults.standard", migration);
  assert.ok(assignment >= 0 && assignment < menuBinding);
  assert.ok(assignment < visibleAssignment);
  assert.ok(migration > assignment && migration < defaultsRead);

  assert.ok(main.includes('"io.github.pg408.codexstatusbar"'));
  assert.ok(main.includes('"com.local.codexstatusbar"'));
  assert.ok(!main.includes('"com.ilyastorun.codexstatusbar"'));
  assert.ok(main.includes("guard PreferenceMigrationRules.migrationRequired(currentDomain: currentDomain) else"));
}

function writeSwiftVerifier() {
  fs.writeFileSync(verifierPath, `
import Foundation

func assertBool(_ actual: Bool, _ expected: Bool, _ label: String) {
    if actual != expected {
        fputs("FAIL \\(label): expected \\(expected), got \\(actual)\\n", stderr)
        exit(1)
    }
}

func assertEqual<T: Equatable>(_ actual: T?, _ expected: T?, _ label: String) {
    if actual != expected {
        fputs("FAIL \\(label): expected \\(String(describing: expected)), got \\(String(describing: actual))\\n", stderr)
        exit(1)
    }
}

func assertNil(_ actual: Any?, _ label: String) {
    if actual != nil {
        fputs("FAIL \\(label): expected nil, got \\(String(describing: actual))\\n", stderr)
        exit(1)
    }
}

@main
struct VerifyPreferenceMigration {
    static func main() {
        let newestLegacy: [String: Any] = [
            "showTimer": true,
            "showStatusText": false,
            "playNotificationSounds": true,
            "hideIdleAfter": 3_600.0,
            "iconStyle": "pet",
            "selectedPetId": "newest-pet",
            "NSStatusItem Preferred Position main-status-item-v1": 42,
            "NSStatusItem Visible main-status-item-v1": false,
            "iconSystem": true,
            "unknownPreference": "drop-me",
        ]
        let olderLegacy: [String: Any] = [
            "showStatusText": true,
            "iconStyle": "codex",
            "selectedPetId": "older-pet",
        ]
        let current: [String: Any] = [
            "showTimer": false,
            "selectedPetId": "current-pet",
        ]

        let plan = PreferenceMigrationRules.makePlan(
            legacyDomains: [newestLegacy, olderLegacy],
            currentDomain: current
        )
        assertBool(plan.shouldWriteMarker, true, "incomplete migration writes marker")
        assertEqual(plan.valuesToWrite["showTimer"] as? Bool, nil, "current timer wins")
        assertEqual(plan.valuesToWrite["selectedPetId"] as? String, nil, "current pet wins")
        assertEqual(plan.valuesToWrite["showStatusText"] as? Bool, false, "newest legacy wins")
        assertEqual(plan.valuesToWrite["playNotificationSounds"] as? Bool, true, "sound migrates")
        assertEqual(plan.valuesToWrite["hideIdleAfter"] as? Double, 3_600.0, "idle timeout migrates")
        assertEqual(plan.valuesToWrite["iconStyle"] as? String, "pet", "icon style migrates")
        assertNil(plan.valuesToWrite["NSStatusItem Preferred Position main-status-item-v1"], "position excluded")
        assertNil(plan.valuesToWrite["NSStatusItem Visible main-status-item-v1"], "visibility excluded")
        assertNil(plan.valuesToWrite["iconSystem"], "removed icon setting excluded")
        assertNil(plan.valuesToWrite["unknownPreference"], "unknown setting excluded")
        assertEqual(plan.valuesToWrite.count, 4, "only missing allowlisted settings migrate")

        let completed = PreferenceMigrationRules.makePlan(
            legacyDomains: [newestLegacy],
            currentDomain: [PreferenceMigrationRules.markerKey: PreferenceMigrationRules.migrationVersion]
        )
        assertBool(completed.shouldWriteMarker, false, "marker makes migration idempotent")
        assertEqual(completed.valuesToWrite.count, 0, "completed migration writes nothing")
        assertBool(
            PreferenceMigrationRules.migrationRequired(
                currentDomain: [PreferenceMigrationRules.markerKey: PreferenceMigrationRules.migrationVersion]
            ),
            false,
            "marker skips legacy domain reads"
        )

        let empty = PreferenceMigrationRules.makePlan(legacyDomains: [], currentDomain: [:])
        assertBool(empty.shouldWriteMarker, true, "empty migration still records completion")
        assertEqual(empty.valuesToWrite.count, 0, "empty migration has no values")

        print("PASS preference migration rules")
    }
}
`);
}

try {
  verifySourceWiring();
  writeSwiftVerifier();
  cp.execFileSync("/usr/bin/swiftc", [rulesPath, verifierPath, "-o", binaryPath], {
    stdio: "inherit",
  });
  cp.execFileSync(binaryPath, { stdio: "inherit" });
  console.log("PASS preference migration source wiring");
} finally {
  fs.rmSync(tmp, { recursive: true, force: true });
}
