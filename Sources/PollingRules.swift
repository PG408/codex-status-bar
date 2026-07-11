import Foundation

struct PollingDecision {
    let shouldEvaluate: Bool
    let shouldRefreshMetadata: Bool
    let shouldRefreshMenu: Bool
    let shouldRunMaintenance: Bool
}

enum PollingRules {
    static func decision(sessionsChanged: Bool,
                         activeTimerSecondChanged: Bool,
                         menuTimerSecondChanged: Bool,
                         maintenanceDue: Bool,
                         menuIsOpen: Bool) -> PollingDecision {
        PollingDecision(
            shouldEvaluate: sessionsChanged || activeTimerSecondChanged || maintenanceDue,
            shouldRefreshMetadata: sessionsChanged || maintenanceDue,
            shouldRefreshMenu: menuIsOpen && (sessionsChanged || menuTimerSecondChanged || maintenanceDue),
            shouldRunMaintenance: maintenanceDue
        )
    }

    static func secondChanged(current: Int?, previous: Int?) -> Bool {
        current != previous
    }

    static func maintenanceIsDue(now: TimeInterval,
                                 previous: TimeInterval?,
                                 interval: TimeInterval) -> Bool {
        guard let previous else { return true }
        return now - previous >= interval
    }
}

struct TimedBooleanCache {
    private var value: Bool?
    private var resolvedAt: TimeInterval?

    mutating func resolve(now: TimeInterval,
                          ttl: TimeInterval,
                          loader: () -> Bool) -> Bool {
        if let value, let resolvedAt, now - resolvedAt < ttl {
            return value
        }

        let loaded = loader()
        value = loaded
        resolvedAt = now
        return loaded
    }

}
