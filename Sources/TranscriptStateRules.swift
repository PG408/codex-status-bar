import Foundation

enum TranscriptTerminalState: Equatable {
    case none
    case completed
    case interrupted
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
