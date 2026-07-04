import Foundation
import SQLite3

struct ThreadMetadata {
    let id: String
    let archived: Bool
    let archivedAt: Double
}

final class ThreadMetadataStore {
    private let sqlitePath: String
    private var lastMTime: Date = .distantPast
    private var lastIdsKey = ""
    private var cache: [String: ThreadMetadata] = [:]

    init(sqlitePath: String) {
        self.sqlitePath = sqlitePath
    }

    func metadata(for ids: [String]) -> [String: ThreadMetadata] {
        let cleanIds = Array(Set(ids.filter { !$0.isEmpty })).sorted()
        let idsKey = cleanIds.joined(separator: "\u{1f}")
        guard !cleanIds.isEmpty else {
            cache.removeAll()
            lastIdsKey = ""
            lastMTime = .distantPast
            return [:]
        }

        guard let mtime = databaseMTime() else {
            cache.removeAll()
            lastIdsKey = idsKey
            lastMTime = .distantPast
            return [:]
        }

        if mtime == lastMTime, idsKey == lastIdsKey {
            return cache
        }

        lastMTime = mtime
        lastIdsKey = idsKey
        cache = readMetadata(ids: cleanIds)
        return cache
    }

    private func databaseMTime() -> Date? {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: sqlitePath),
              let baseMTime = attrs[.modificationDate] as? Date else {
            return nil
        }

        return [sqlitePath + "-wal", sqlitePath + "-shm"].reduce(baseMTime) { current, path in
            guard let attrs = try? fm.attributesOfItem(atPath: path),
                  let mtime = attrs[.modificationDate] as? Date else {
                return current
            }
            return max(current, mtime)
        }
    }

    private func readMetadata(ids: [String]) -> [String: ThreadMetadata] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(sqlitePath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK,
              let db else {
            if db != nil { sqlite3_close(db) }
            return [:]
        }
        defer { sqlite3_close(db) }

        let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
        let sql = "select id, archived, archived_at from threads where id in (\(placeholders))"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return [:]
        }
        defer { sqlite3_finalize(statement) }

        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, id) in ids.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), id, -1, transient)
        }

        var result: [String: ThreadMetadata] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let rawId = sqlite3_column_text(statement, 0) else { continue }
            let id = String(cString: rawId)
            let archived = sqlite3_column_int(statement, 1) != 0
            let archivedAt = sqlite3_column_type(statement, 2) == SQLITE_NULL ? 0 : sqlite3_column_double(statement, 2)
            result[id] = ThreadMetadata(id: id, archived: archived, archivedAt: archivedAt)
        }
        return result
    }
}
