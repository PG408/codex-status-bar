import Foundation

struct SessionNotificationSnapshot: Equatable {
    let state: String
    let timestamp: Double
}

enum NotificationSoundRules {
    static func shouldPlayCompletion(
        previous: [String: SessionNotificationSnapshot],
        current: [String: SessionNotificationSnapshot],
        observationStartedAt: Double
    ) -> Bool {
        current.contains { sessionId, snapshot in
            guard snapshot.state == "done" else { return false }
            guard let prior = previous[sessionId] else {
                return snapshot.timestamp >= observationStartedAt
            }
            return prior.state != "done" && snapshot.timestamp >= prior.timestamp
        }
    }
}
