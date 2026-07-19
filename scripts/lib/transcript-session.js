const fs = require("fs");

const maxSessionMetaBytes = 1024 * 1024;
const readChunkBytes = 16 * 1024;

function readSessionMeta(filePath) {
  if (!filePath || typeof filePath !== "string") return null;

  let fd;
  try {
    fd = fs.openSync(filePath, "r");
    const chunks = [];
    let bytesRead = 0;

    while (bytesRead < maxSessionMetaBytes) {
      const chunk = Buffer.alloc(Math.min(readChunkBytes, maxSessionMetaBytes - bytesRead));
      const count = fs.readSync(fd, chunk, 0, chunk.length, bytesRead);
      if (count === 0) break;
      const data = chunk.subarray(0, count);
      const newline = data.indexOf(10);
      chunks.push(newline >= 0 ? data.subarray(0, newline) : data);
      bytesRead += count;
      if (newline >= 0) {
        return parseSessionMeta(Buffer.concat(chunks).toString("utf8"));
      }
    }

    return parseSessionMeta(Buffer.concat(chunks).toString("utf8"));
  } catch {
    return null;
  } finally {
    if (fd !== undefined) fs.closeSync(fd);
  }
}

function parseSessionMeta(line) {
  try {
    const object = JSON.parse(line);
    if (object.type !== "session_meta" || !object.payload || typeof object.payload !== "object") {
      return null;
    }
    return object.payload;
  } catch {
    return null;
  }
}

function normalizeHookPayload(payload) {
  const transcriptPath = typeof payload.transcript_path === "string" ? payload.transcript_path : "";
  const meta = readSessionMeta(transcriptPath);
  if (!meta) return { payload, subagentTranscript: "", subagentKey: "" };

  const threadId = typeof meta.id === "string" ? meta.id : "";
  const sessionId = String(payload.session_id || payload.sessionId || "");
  const subagentSource = meta.source && typeof meta.source === "object" ? meta.source.subagent : null;
  const isSubagent = meta.thread_source === "subagent" || Boolean(subagentSource);
  const derivedSubagent = isSubagent && !payload.agent_id && !payload.agent_type;
  const normalized = { ...payload };

  if (isSubagent && threadId && sessionId && threadId !== sessionId) {
    delete normalized.transcript_path;
  }
  if (derivedSubagent) {
    normalized.agent_id = threadId;
    normalized.agent_type = subagentType(subagentSource);
  }

  return {
    payload: normalized,
    subagentTranscript: derivedSubagent ? transcriptPath : "",
    subagentKey: derivedSubagent ? threadId : "",
  };
}

function subagentType(source) {
  if (!source || typeof source !== "object") return "subagent";
  if (typeof source.other === "string" && source.other) return source.other;
  return "subagent";
}

module.exports = { normalizeHookPayload, parseSessionMeta, readSessionMeta };
