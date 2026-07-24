import Foundation

final class SessionIndexStore {
    private let path: String
    private var lastMTime: Date?
    private var cachedIds: Set<String> = []

    init(path: String) {
        self.path = path
    }

    func sessionIds() -> Set<String> {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: path),
              let mtime = attrs[.modificationDate] as? Date else {
            lastMTime = nil
            cachedIds.removeAll()
            return []
        }
        if mtime == lastMTime {
            return cachedIds
        }

        lastMTime = mtime
        guard let data = fm.contents(atPath: path),
              let jsonl = String(data: data, encoding: .utf8) else {
            cachedIds.removeAll()
            return []
        }
        cachedIds = SessionVisibilityRules.indexedSessionIds(from: jsonl)
        return cachedIds
    }
}
