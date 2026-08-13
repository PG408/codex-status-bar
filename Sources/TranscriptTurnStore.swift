import Foundation

final class TranscriptTurnStore {
    private static let maximumReadBytes: UInt64 = 256 * 1024

    private struct Entry {
        var processedBytes: UInt64
        var snapshot: TranscriptTurnSnapshot
    }

    private var entries: [String: Entry] = [:]

    func snapshot(for path: String) -> TranscriptTurnSnapshot {
        guard !path.isEmpty,
              let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let fileSize = (attributes[.size] as? NSNumber)?.uint64Value else {
            entries[path] = nil
            return .unknown
        }

        var entry = entries[path] ?? Entry(processedBytes: 0, snapshot: .unknown)
        if fileSize < entry.processedBytes {
            entry = Entry(processedBytes: 0, snapshot: .unknown)
        }
        guard fileSize > entry.processedBytes,
              let handle = FileHandle(forReadingAtPath: path) else {
            entries[path] = entry
            return entry.snapshot
        }
        defer { try? handle.close() }

        do {
            if entry.processedBytes == 0, fileSize > Self.maximumReadBytes {
                try handle.seek(toOffset: 0)
                if let head = try handle.read(upToCount: Int(Self.maximumReadBytes)),
                   let newline = head.lastIndex(of: 0x0A) {
                    let text = String(decoding: head.prefix(through: newline), as: UTF8.self)
                    entry.snapshot = TranscriptStateRules.turnSnapshot(in: text, after: entry.snapshot)
                }
            }

            let unreadBytes = fileSize - entry.processedBytes
            let readOffset = unreadBytes > Self.maximumReadBytes ?
                fileSize - Self.maximumReadBytes : entry.processedBytes
            try handle.seek(toOffset: readOffset)
            guard let data = try handle.read(upToCount: Int(Self.maximumReadBytes)), !data.isEmpty else {
                entries[path] = entry
                return entry.snapshot
            }

            guard let newline = data.lastIndex(of: 0x0A) else {
                let text = String(decoding: data, as: UTF8.self)
                let snapshot = TranscriptStateRules.turnSnapshot(in: text, after: entry.snapshot)
                guard snapshot != entry.snapshot else {
                    entries[path] = entry
                    return entry.snapshot
                }
                entry.snapshot = snapshot
                entry.processedBytes = readOffset + UInt64(data.count)
                entries[path] = entry
                return entry.snapshot
            }
            let completeData = data.prefix(through: newline)
            let text = String(decoding: completeData, as: UTF8.self)
            entry.snapshot = TranscriptStateRules.turnSnapshot(in: text, after: entry.snapshot)
            entry.processedBytes = readOffset + UInt64(completeData.count)
            entries[path] = entry
            return entry.snapshot
        } catch {
            entries[path] = entry
            return entry.snapshot
        }
    }

    func retain(paths: Set<String>) {
        entries = entries.filter { paths.contains($0.key) }
    }
}
