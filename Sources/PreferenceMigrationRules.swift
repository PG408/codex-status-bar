import Foundation

struct PreferenceMigrationPlan {
    let valuesToWrite: [String: Any]
    let shouldWriteMarker: Bool
}

enum PreferenceMigrationRules {
    static let markerKey = "legacyPreferencesMigrationVersion"
    static let migrationVersion = 1

    private static let allowedKeys: Set<String> = [
        "showTimer",
        "showStatusText",
        "playNotificationSounds",
        "hideIdleAfter",
        "iconStyle",
        "selectedPetId",
    ]

    static func migrationRequired(currentDomain: [String: Any]) -> Bool {
        markerVersion(in: currentDomain) < migrationVersion
    }

    static func makePlan(legacyDomains: [[String: Any]],
                         currentDomain: [String: Any]) -> PreferenceMigrationPlan {
        guard migrationRequired(currentDomain: currentDomain) else {
            return PreferenceMigrationPlan(valuesToWrite: [:], shouldWriteMarker: false)
        }

        var valuesToWrite: [String: Any] = [:]
        for legacyDomain in legacyDomains {
            for key in allowedKeys where currentDomain[key] == nil && valuesToWrite[key] == nil {
                if let value = legacyDomain[key] {
                    valuesToWrite[key] = value
                }
            }
        }
        return PreferenceMigrationPlan(valuesToWrite: valuesToWrite, shouldWriteMarker: true)
    }

    private static func markerVersion(in domain: [String: Any]) -> Int {
        if let version = domain[markerKey] as? Int {
            return version
        }
        return (domain[markerKey] as? NSNumber)?.intValue ?? 0
    }
}
