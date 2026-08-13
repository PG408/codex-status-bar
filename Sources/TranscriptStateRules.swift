import Foundation

enum TranscriptTerminalState: Equatable {
    case none
    case completed
    case interrupted
}

enum TranscriptTurnState: Equatable {
    case unknown
    case running
    case completed
    case interrupted
}

struct TranscriptTurnSnapshot: Equatable {
    let state: TranscriptTurnState
    let timestamp: Double

    static let unknown = TranscriptTurnSnapshot(state: .unknown, timestamp: 0)
}

enum TranscriptStateRules {
    static func terminalState(in text: String, after stateTimestamp: Double) -> TranscriptTerminalState {
        var latestTimestamp = stateTimestamp
        var latestState = TranscriptTerminalState.none

        for line in text.split(separator: "\n") {
            guard let data = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  object["type"] as? String == "event_msg",
                  let payload = object["payload"] as? [String: Any],
                  let event = payload["type"] as? String,
                  ["task_started", "task_complete", "turn_aborted"].contains(event),
                  let timestamp = eventTimestamp(object: object, payload: payload, event: event),
                  timestamp > latestTimestamp else {
                continue
            }

            latestTimestamp = timestamp
            switch event {
            case "task_complete":
                latestState = .completed
            case "turn_aborted":
                latestState = .interrupted
            default:
                latestState = .none
            }
        }

        return latestState
    }

    static func turnState(in text: String) -> TranscriptTurnState {
        turnSnapshot(in: text).state
    }

    static func turnSnapshot(
        in text: String,
        after previous: TranscriptTurnSnapshot = .unknown
    ) -> TranscriptTurnSnapshot {
        var latest = previous

        for line in text.split(separator: "\n") {
            guard let data = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  object["type"] as? String == "event_msg",
                  let payload = object["payload"] as? [String: Any],
                  let event = payload["type"] as? String,
                  ["task_started", "task_complete", "turn_aborted"].contains(event),
                  let timestamp = turnEventTimestamp(object: object, payload: payload, event: event),
                  timestamp > latest.timestamp else {
                continue
            }

            let state: TranscriptTurnState
            switch event {
            case "task_started":
                state = .running
            case "task_complete":
                state = .completed
            default:
                state = .interrupted
            }
            latest = TranscriptTurnSnapshot(state: state, timestamp: timestamp)
        }

        return latest
    }

    private static func turnEventTimestamp(
        object: [String: Any],
        payload: [String: Any],
        event: String
    ) -> Double? {
        if let value = object["timestamp"] as? String,
           let timestamp = ISO8601DateFormatter().date(from: value)?.timeIntervalSince1970 {
            return timestamp
        }
        return eventTimestamp(object: object, payload: payload, event: event)
    }

    private static func eventTimestamp(
        object: [String: Any],
        payload: [String: Any],
        event: String
    ) -> Double? {
        let payloadKey = event == "task_started" ? "started_at" : "completed_at"
        if let timestamp = (payload[payloadKey] as? NSNumber)?.doubleValue {
            return timestamp
        }
        guard let value = object["timestamp"] as? String else { return nil }
        return ISO8601DateFormatter().date(from: value)?.timeIntervalSince1970
    }
}
