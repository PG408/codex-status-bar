const fs = require("fs");

const chunkBytes = 64 * 1024;
const maximumLineBytes = 1024 * 1024;

function positiveNumber(value) {
  return typeof value === "number" && Number.isFinite(value) && value > 0 ? value : 0;
}

function parseTaskRecord(line) {
  try {
    const object = JSON.parse(line);
    const payload = object.payload;
    if (object.type !== "event_msg" || !payload || typeof payload.turn_id !== "string") return null;
    const states = { task_started: "running", task_complete: "completed", turn_aborted: "interrupted" };
    const state = states[payload.type];
    if (!state) return null;
    const timestamp = positiveNumber(Date.parse(object.timestamp) / 1000);
    const startedAt = positiveNumber(payload.started_at) || (state === "running" ? timestamp : 0);
    return {
      turnId: payload.turn_id,
      state,
      startedAt,
      completedAt: positiveNumber(payload.completed_at) || (state !== "running" ? timestamp : 0),
      durationMs: positiveNumber(payload.duration_ms),
    };
  } catch {
    return null;
  }
}

// 逆序分块读取，只拼接有界的行；大型压缩记录不占用同等大小的内存。
function* reverseLines(fd) {
  let offset = fs.fstatSync(fd).size;
  let fragments = [];
  let length = 0;
  let skipping = false;
  while (offset > 0) {
    const size = Math.min(chunkBytes, offset);
    offset -= size;
    const buffer = Buffer.allocUnsafe(size);
    const count = fs.readSync(fd, buffer, 0, size, offset);
    let end = count;
    while (end > 0) {
      const newline = buffer.lastIndexOf(10, end - 1);
      const part = buffer.subarray(newline + 1, end);
      length += part.length;
      if (length > maximumLineBytes) {
        fragments = [];
        skipping = true;
      } else if (!skipping) {
        fragments.push(part);
      }
      if (newline >= 0) {
        if (!skipping && length > 0) yield Buffer.concat(fragments.reverse(), length).toString("utf8");
        fragments = [];
        length = 0;
        skipping = false;
        end = newline;
      } else {
        break;
      }
    }
  }
  if (!skipping && length > 0) yield Buffer.concat(fragments.reverse(), length).toString("utf8");
}

function readTaskRecord(transcript, turnId = "", previous = null, refresh = false) {
  const cached = previous && previous.turnId === turnId && previous.startedAt > 0 ? previous : null;
  if (!refresh && cached?.transcript === transcript) return cached;
  let fd;
  let latest = null;
  try {
    if (!transcript) return cached;
    fd = fs.openSync(transcript, "r");
    for (const line of reverseLines(fd)) {
      const record = parseTaskRecord(line);
      if (!record || (turnId && record.turnId !== turnId)) continue;
      if (!latest) latest = { ...record, transcript };
      if (!latest.startedAt && record.turnId === latest.turnId) latest.startedAt = record.startedAt;
      if (latest.startedAt > 0) return latest;
      if (!turnId && record.turnId !== latest.turnId) break;
    }
    return latest ? { ...latest, startedAt: latest.startedAt || cached?.startedAt || 0 } : cached;
  } catch {
    return cached;
  } finally {
    if (fd !== undefined) fs.closeSync(fd);
  }
}

module.exports = { readTaskRecord };
