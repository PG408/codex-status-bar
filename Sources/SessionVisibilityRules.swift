import Foundation

enum SessionVisibilityRules {
    static func shouldSuppress(transcript: String, isInSessionIndex: Bool) -> Bool {
        transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isInSessionIndex
    }

    static func indexedSessionIds(from jsonl: String) -> Set<String> {
        var ids: Set<String> = []
        for line in jsonl.split(whereSeparator: { $0.isNewline }) {
            guard let data = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = object["id"] as? String else {
                continue
            }
            let normalized = id.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.isEmpty {
                ids.insert(normalized)
            }
        }
        return ids
    }
}
