import Foundation

struct ChatGPTViewActivityEvent: Equatable {
    let sessionId: String
    let isActive: Bool
}

enum ChatGPTActivityLogRules {
    static func viewActivityEvent(from line: String) -> ChatGPTViewActivityEvent? {
        guard line.contains("thread_stream_view_activity_changed"),
              let sessionId = field("conversationId", in: line),
              !sessionId.isEmpty,
              sessionId != "null",
              let active = field("active", in: line) else { return nil }
        guard active == "true" || active == "false" else { return nil }
        return ChatGPTViewActivityEvent(sessionId: sessionId, isActive: active == "true")
    }

    private static func field(_ name: String, in line: String) -> String? {
        let prefix = name + "="
        return line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            .first(where: { $0.hasPrefix(prefix) })
            .map { String($0.dropFirst(prefix.count)) }
    }
}

final class ChatGPTActivityLogMonitor {
    private let rootPath: String
    private let discoveryInterval: TimeInterval
    private let initialTailBytes: UInt64
    private var logFiles: [String] = []
    private var offsets: [String: UInt64] = [:]
    private var partialLines: [String: String] = [:]
    private var activityBySession: [String: Bool] = [:]
    private var lastDiscoveryAt: TimeInterval?

    init(rootPath: String,
         discoveryInterval: TimeInterval = 5,
         initialTailBytes: UInt64 = 2 * 1024 * 1024) {
        self.rootPath = rootPath
        self.discoveryInterval = discoveryInterval
        self.initialTailBytes = initialTailBytes
    }

    func refresh(now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        if lastDiscoveryAt == nil || now - (lastDiscoveryAt ?? 0) >= discoveryInterval {
            discoverLogFiles()
            lastDiscoveryAt = now
        }

        var changed = false
        for path in logFiles {
            changed = readNewContent(at: path) || changed
        }
        return changed
    }

    func isViewActive(sessionId: String) -> Bool? {
        activityBySession[sessionId]
    }

    private func discoverLogFiles() {
        let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            logFiles = []
            return
        }

        var candidates: [(path: String, modifiedAt: Date)] = []
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            guard name.hasSuffix(".log"), name.contains("-t0-") else { continue }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            candidates.append((url.path, values?.contentModificationDate ?? .distantPast))
        }

        logFiles = candidates
            .sorted { $0.modifiedAt < $1.modifiedAt }
            .suffix(8)
            .map(\.path)
    }

    private func readNewContent(at path: String) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = (attributes[.size] as? NSNumber)?.uint64Value else { return false }

        var offset = offsets[path]
        var discardLeadingPartialLine = false
        if offset == nil || (offset ?? 0) > size {
            let initialOffset = size > initialTailBytes ? size - initialTailBytes : 0
            offset = initialOffset
            partialLines[path] = ""
            discardLeadingPartialLine = initialOffset > 0
        }
        guard let start = offset, start < size,
              let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else {
            offsets[path] = size
            return false
        }
        defer { try? handle.close() }

        do {
            try handle.seek(toOffset: start)
            let data = try handle.readToEnd() ?? Data()
            offsets[path] = start + UInt64(data.count)
            guard let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return false }
            return consume(chunk, path: path, discardLeadingPartialLine: discardLeadingPartialLine)
        } catch {
            return false
        }
    }

    private func consume(_ chunk: String,
                         path: String,
                         discardLeadingPartialLine: Bool) -> Bool {
        var text = (partialLines[path] ?? "") + chunk
        if discardLeadingPartialLine, let newline = text.firstIndex(of: "\n") {
            text = String(text[text.index(after: newline)...])
        }

        let endsWithNewline = text.hasSuffix("\n")
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        partialLines[path] = endsWithNewline ? "" : (lines.popLast() ?? "")

        var changed = false
        for line in lines {
            guard let event = ChatGPTActivityLogRules.viewActivityEvent(from: line) else { continue }
            if activityBySession[event.sessionId] != event.isActive {
                activityBySession[event.sessionId] = event.isActive
                changed = true
            }
        }
        return changed
    }
}
