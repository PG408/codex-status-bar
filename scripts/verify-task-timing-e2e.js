#!/usr/bin/env node
const assert = require("assert/strict");
const cp = require("child_process");
const fs = require("fs");
const path = require("path");

// 失败风险：压缩清零、重复提交重置、串用其他轮次、日志切换丢失起点、
// 大行遮住开始事件、半行写入、记录缺失，以及完成时长被本地时钟替代。
const root = path.resolve(__dirname, "..");
const output = path.join(root, ".tmp", "task-timing-e2e");
fs.mkdirSync(output, { recursive: true });
const runDir = fs.mkdtempSync(path.join(output, "run-"));
const sessionId = "task-timing-e2e";
const index = path.join(runDir, "session_index.jsonl");
const transcript = path.join(runDir, "task.jsonl");
const statePath = path.join(runDir, "state.d", `${sessionId}.json`);
fs.writeFileSync(index, `${JSON.stringify({ id: sessionId })}\n`);
const origin = Math.floor(Date.now() / 1000) - 900;
const results = [];

function append(event, payload = {}, file = transcript) {
  fs.appendFileSync(file, `${JSON.stringify({
    timestamp: new Date((payload.completed_at || payload.started_at || origin) * 1000).toISOString(),
    type: "event_msg",
    payload: { type: event, ...payload },
  })}\n`);
}

function hook(event, payload = {}, file = transcript) {
  const lifecycle = ["SessionStart", "SessionEnd"].includes(event);
  const result = cp.spawnSync(process.execPath, [
    path.join(root, "scripts", lifecycle ? "codex-lifecycle-writer.js" : "codex-status-writer.js"), event,
  ], {
    input: JSON.stringify({ session_id: sessionId, transcript_path: file, cwd: runDir, ...payload }),
    encoding: "utf8",
    env: {
      ...process.env,
      CODEX_STATUSBAR_DIR: runDir,
      CODEX_SESSION_INDEX_PATH: index,
      CODEX_STATUSBAR_DISABLE_AUTO_LAUNCH: "1",
      CODEX_STATUSBAR_MIN_TOOL_VISIBLE_MS: "0",
      CODEX_STATUSBAR_MAX_TOOL_VISIBLE_MS: "0",
    },
    timeout: 10000,
  });
  assert.equal(result.status, 0, result.stderr || result.error?.message);
  return JSON.parse(fs.readFileSync(statePath, "utf8"));
}

function check(name, verify) {
  try {
    verify();
    results.push({ name, passed: true });
    console.log(`PASS ${name}`);
  } catch (error) {
    results.push({ name, passed: false, error: error.message });
    console.error(`FAIL ${name}: ${error.message}`);
  }
}

append("task_started", { turn_id: "turn-a", started_at: origin });
check("task record supplies the original start", () => {
  const state = hook("UserPromptSubmit", { turn_id: "turn-a" });
  assert.equal(state.startedAt, origin);
  assert.equal(state.statusFacts.main.startedAt, origin);
});
check("compaction SessionStart keeps the running task", () => {
  hook("PreCompact", { turn_id: "turn-a" });
  const state = hook("SessionStart", { source: "compact" });
  assert.equal(state.state, "thinking");
  assert.equal(state.turnId, "turn-a");
  assert.equal(state.startedAt, origin);
});
check("PostCompact and tool hooks keep task time", () => {
  hook("PostCompact", { turn_id: "turn-a" });
  const state = hook("PreToolUse", { turn_id: "turn-a", tool_name: "Bash" });
  assert.equal(state.startedAt, origin);
});
check("same-turn prompt replay does not restart the clock", () => {
  assert.equal(hook("UserPromptSubmit", { turn_id: "turn-a" }).startedAt, origin);
});
check("large compaction rows do not hide the start", () => {
  fs.appendFileSync(transcript, `${JSON.stringify({ type: "compacted", payload: { message: "x".repeat(2 * 1024 * 1024) } })}\n`);
  const rotated = `${transcript}.rotated`;
  fs.copyFileSync(transcript, rotated);
  assert.equal(hook("PreToolUse", { turn_id: "turn-a", tool_name: "Bash" }, rotated).startedAt, origin);
});
check("missing start in a rotated log keeps the same recorded task", () => {
  const rotated = `${transcript}.continuation`;
  fs.writeFileSync(rotated, `${JSON.stringify({ type: "compacted", payload: {} })}\n`);
  const state = hook("PreToolUse", { turn_id: "turn-a", tool_name: "Bash" }, rotated);
  assert.equal(state.startedAt, origin);
  const resumed = hook("SessionStart", { source: "compact" }, rotated);
  assert.equal(resumed.startedAt, origin);
  assert.equal(resumed.turnId, "turn-a");
});
check("pending input survives compaction without a visible timer", () => {
  hook("PreToolUse", { turn_id: "turn-a", tool_name: "request_user_input", tool_use_id: "input-1" });
  const state = hook("SessionStart", { source: "compact" });
  assert.equal(state.state, "needs_input");
  assert.equal(state.startedAt, 0);
  assert.equal(state.statusFacts.main.startedAt, origin);
  assert.equal(hook("PostToolUse", {
    turn_id: "turn-a", tool_name: "request_user_input", tool_use_id: "input-1",
  }).startedAt, origin);
});
check("completion uses recorded duration", () => {
  append("task_complete", { turn_id: "turn-a", started_at: origin, completed_at: origin + 600, duration_ms: 600123 });
  const state = hook("Stop", { turn_id: "turn-a" });
  assert.equal(state.startedAt, 0);
  assert.equal(state.taskRecord.durationMs, 600123);
});
check("a new turn has a new recorded start", () => {
  append("task_started", { turn_id: "turn-b", started_at: origin + 650 });
  const state = hook("UserPromptSubmit", { turn_id: "turn-b" });
  assert.equal(state.startedAt, origin + 650);
});
check("late previous-turn events do not replace current timing", () => {
  const state = hook("PostToolUse", { turn_id: "turn-a", tool_name: "Bash" });
  assert.equal(state.turnId, "turn-b");
  assert.equal(state.startedAt, origin + 650);
});
check("partial trailing JSON does not hide a task start", () => {
  fs.appendFileSync(transcript, '{"type":"event_msg","payload":');
  const state = hook("SessionStart", { source: "compact" });
  assert.equal(state.turnId, "turn-b");
  assert.equal(state.startedAt, origin + 650);
});
check("missing task records preserve legacy hook support", () => {
  const state = hook("UserPromptSubmit", { turn_id: "legacy" }, path.join(runDir, "missing.jsonl"));
  assert.ok(state.startedAt > 0);
  assert.equal(state.turnId, "legacy");
  const repeated = hook("UserPromptSubmit", { turn_id: "legacy" }, path.join(runDir, "missing.jsonl"));
  assert.equal(repeated.startedAt, state.startedAt);
  const restored = hook("SessionStart", { source: "compact" }, path.join(runDir, "missing.jsonl"));
  assert.equal(restored.startedAt, state.startedAt);
});
check("a late task record corrects an earlier hook fallback", () => {
  const file = path.join(runDir, "late.jsonl");
  const initial = hook("UserPromptSubmit", { turn_id: "late-turn" }, file);
  assert.ok(initial.startedAt > origin);
  append("task_started", { turn_id: "late-turn", started_at: origin }, file);
  assert.equal(hook("PreToolUse", { turn_id: "late-turn", tool_name: "Bash" }, file).startedAt, origin);
});
check("normal startup after completion does not restore a running timer", () => {
  const file = path.join(runDir, "complete.jsonl");
  append("task_complete", { turn_id: "late-turn", started_at: origin, completed_at: origin + 100, duration_ms: 100321 }, file);
  const state = hook("SessionStart", { source: "resume" }, file);
  assert.equal(state.state, "idle");
  assert.equal(state.startedAt, 0);
  assert.equal(state.taskRecord.durationMs, 100321);
});

check("App reads task time without another hook and survives restart", () => {
  const file = path.join(runDir, "display.jsonl");
  append("task_started", { turn_id: "earlier", started_at: origin - 100 }, file);
  fs.appendFileSync(file, `${JSON.stringify({ type: "compacted", payload: { message: "x".repeat(2 * 1024 * 1024) } })}\n`);
  append("task_started", { turn_id: "display-turn", started_at: origin }, file);
  fs.appendFileSync(file, `${JSON.stringify({ type: "compacted", payload: { message: "x".repeat(2 * 1024 * 1024) } })}\n`);
  fs.appendFileSync(file, '{"type":"event_msg","payload":');
  const source = path.join(runDir, "VerifyTaskTiming.swift");
  const binary = path.join(runDir, "verify-task-timing");
  fs.writeFileSync(source, `
import Foundation

@main
struct VerifyTaskTiming {
    static func main() throws {
        let path = ${JSON.stringify(file)}
        let expected = Double(${origin})
        let store = TaskTimingStore()
        precondition(store.startedAt(transcript: path, turnId: "display-turn") == expected)
        precondition(store.startedAt(transcript: path, turnId: "display-turn") == expected)
        precondition(TaskTimingStore().startedAt(transcript: path, turnId: "display-turn") == expected)
        precondition(store.startedAt(transcript: path, turnId: "absent") == nil)
        precondition(store.startedAt(transcript: path, turnId: "earlier") == expected - 100)
        let late = path + ".late"
        try "".write(toFile: late, atomically: true, encoding: .utf8)
        precondition(store.startedAt(transcript: late, turnId: "late") == nil)
        try "{\\"type\\":\\"event_msg\\",\\"payload\\":{\\"type\\":\\"task_started\\",\\"turn_id\\":\\"late\\",\\"started_at\\":${origin}}}\\n"
            .write(toFile: late, atomically: true, encoding: .utf8)
        precondition(store.startedAt(transcript: late, turnId: "late") == expected)
        print("PASS native task timer record lookup")
    }
}
`);
  const compile = cp.spawnSync("/usr/bin/swiftc", ["-O", path.join(root, "Sources", "TaskTimingStore.swift"), source, "-o", binary], {
    encoding: "utf8", timeout: 120000,
  });
  assert.equal(compile.status, 0, compile.stderr);
  const run = cp.spawnSync(binary, [], { encoding: "utf8", timeout: 10000 });
  assert.equal(run.status, 0, run.stderr || run.error?.message);
});

const realStatePath = process.argv[2];
if (realStatePath) check("real task log survives the complete compaction hook sequence", () => {
  const actual = JSON.parse(fs.readFileSync(realStatePath, "utf8"));
  const turnId = actual.statusFacts?.main?.turnId || actual.turnId;
  const events = fs.readFileSync(actual.transcript, "utf8").split("\n").flatMap((line) => {
    try { return [JSON.parse(line)]; } catch { return []; }
  });
  const event = events.find((item) => item.type === "event_msg" &&
    item.payload?.type === "task_started" && item.payload.turn_id === turnId);
  assert.ok(event, "real task_started must exist");
  const start = event.payload.started_at;
  hook("UserPromptSubmit", { turn_id: turnId }, actual.transcript);
  const before = hook("PreCompact", { turn_id: turnId }, actual.transcript);
  const copy = path.join(runDir, "real-active.jsonl");
  // 完成后的真实记录仅在隔离副本中移除终止事件，重放运行中的恢复路径。
  fs.writeFileSync(copy, events.filter((item) => !(item.type === "event_msg" &&
    item.payload?.turn_id === turnId && ["task_complete", "turn_aborted"].includes(item.payload.type)))
    .map((item) => JSON.stringify(item)).join("\n") + "\n");
  const resumed = hook("SessionStart", { source: "compact" }, copy);
  const after = hook("PreToolUse", { turn_id: turnId, tool_name: "Bash" }, copy);
  assert.equal(before.startedAt, start);
  assert.equal(resumed.startedAt, start);
  assert.equal(after.startedAt, start);
  results.push({ name: "real task timing evidence", passed: true, turnId, expectedStart: start,
    previousBarStart: actual.startedAt, before: before.startedAt, resumed: resumed.startedAt, after: after.startedAt });
});

const report = { generatedAt: new Date().toISOString(), runDir, origin, results };
fs.writeFileSync(path.join(runDir, "report.json"), JSON.stringify(report, null, 2));
fs.writeFileSync(path.join(output, "latest.json"), JSON.stringify(report, null, 2));
console.log(`Report: ${path.join(runDir, "report.json")}`);
process.exitCode = results.every((result) => result.passed) ? 0 : 1;
