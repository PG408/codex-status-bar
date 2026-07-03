import Foundation

enum TranscriptStateRules {
    static func lineShowsUserInterrupt(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if let data = trimmed.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return jsonLineShowsUserInterrupt(object)
        }

        return trimmed.localizedCaseInsensitiveContains("interrupted by user")
    }

    private static func jsonLineShowsUserInterrupt(_ object: [String: Any]) -> Bool {
        guard object["type"] as? String == "event_msg",
              let payload = object["payload"] as? [String: Any],
              payload["type"] as? String == "turn_aborted" else {
            return false
        }
        return (payload["reason"] as? String) == "interrupted"
    }
}
