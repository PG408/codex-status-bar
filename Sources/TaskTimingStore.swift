import Foundation

final class TaskTimingStore {
    private struct Entry {
        let turnId: String
        let fileSize: UInt64
        let startedAt: Double?
    }

    private var entries: [String: Entry] = [:]
    private let chunkBytes = 64 * 1024
    private let maximumLineBytes = 1024 * 1024

    func startedAt(transcript: String, turnId: String) -> Double? {
        guard !transcript.isEmpty, !turnId.isEmpty else { return nil }
        let cached = entries[transcript]
        if cached?.turnId == turnId, let startedAt = cached?.startedAt {
            return startedAt
        }
        guard let handle = FileHandle(forReadingAtPath: transcript) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return nil }
        if cached?.turnId == turnId, cached?.fileSize == size { return nil }

        let start = scan(handle: handle, size: size, turnId: turnId)
        entries[transcript] = Entry(turnId: turnId, fileSize: size, startedAt: start)
        return start
    }

    func retain(paths: Set<String>) {
        entries = entries.filter { paths.contains($0.key) }
    }

    private func scan(handle: FileHandle, size: UInt64, turnId: String) -> Double? {
        var offset = size
        var suffix = Data()
        var skipping = false
        while offset > 0 {
            let count = min(UInt64(chunkBytes), offset)
            offset -= count
            guard (try? handle.seek(toOffset: offset)) != nil,
                  let data = try? handle.read(upToCount: Int(count)) else { return nil }
            var end = data.endIndex
            for newline in data.indices.reversed() where data[newline] == 0x0A {
                let part = data[(newline + 1)..<end]
                if !skipping, part.count + suffix.count <= maximumLineBytes {
                    var line = Data(part)
                    line.append(suffix)
                    if let start = taskStart(in: line, turnId: turnId) { return start }
                }
                suffix.removeAll(keepingCapacity: true)
                skipping = false
                end = newline
            }
            if !skipping, end + suffix.count <= maximumLineBytes {
                var partial = Data(data[..<end])
                partial.append(suffix)
                suffix = partial
            } else {
                suffix.removeAll(keepingCapacity: true)
                skipping = true
            }
        }
        return skipping ? nil : taskStart(in: suffix, turnId: turnId)
    }

    private func taskStart(in data: Data, turnId: String) -> Double? {
        guard !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["type"] as? String == "event_msg",
              let payload = object["payload"] as? [String: Any],
              payload["turn_id"] as? String == turnId,
              let event = payload["type"] as? String,
              ["task_started", "task_complete", "turn_aborted"].contains(event) else { return nil }
        if let start = (payload["started_at"] as? NSNumber)?.doubleValue,
           start.isFinite, start > 0 { return start }
        guard event == "task_started", let text = object["timestamp"] as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date.timeIntervalSince1970 }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)?.timeIntervalSince1970
    }
}
