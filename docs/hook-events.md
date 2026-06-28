# Codex Hook Event Model

This document defines the Phase 1 single-state-file model. The app still reads one file:

```text
~/.codex/statusbar/state.json
```

The writer is intentionally small. Each hook invocation receives one JSON payload on stdin, updates the state file atomically when the event is relevant, and exits quickly.

## State Fields

The state file contains only display metadata:

| Field | Purpose |
|---|---|
| `state` | One of `idle`, `done`, `thinking`, `tool`, `permission`, or `waiting`. |
| `label` | Short menu bar label such as `Codex thinking`, `Running command`, or `Awaiting permission`. |
| `tool` | Raw tool name when available. |
| `project` | Basename of `cwd`, `working_directory`, or `current_working_directory`. |
| `sessionId` | Sanitized `session_id` or `sessionId`. |
| `activeSessionId` | Current session allowed to update active turn state. |
| `activeTurnId` | Current turn allowed to update tool/stop state. |
| `startedAt` | Unix seconds for timer display; `0` when no timer should be shown. |
| `ts` | Unix seconds when the displayed state was written. |
| `visibleUntilMs` | Optional upper bound for a short tool label. |
| `minVisibleUntilMs` | Optional lower bound for tool or permission visibility. |

The writer does not store prompts, command output, transcript contents, or secrets.

## Event Transitions

| Event | Matcher | Writer behavior |
|---|---:|---|
| `SessionStart` | none | No state mutation in Phase 1. The event is installed so later lifecycle work can use it without changing hook coverage. |
| `UserPromptSubmit` | none | Starts an active turn. Writes `thinking`, `Codex thinking`, a non-zero `startedAt`, `activeSessionId`, and `activeTurnId`. |
| `PreToolUse` | `*` | If the payload matches the active session/turn, writes `tool` and maps the tool name to a short label. Background turns are ignored. |
| `PostToolUse` | `*` | If the payload matches the active session/turn, returns to `thinking`. It preserves the active turn timer. |
| `PermissionRequest` | `*` | If the payload belongs to the active session, writes `permission`, `Awaiting permission`, and clears `startedAt`. |
| `Stop` | none | If the payload matches the active session/turn, writes `done`, `Done`, and clears `startedAt`. |
| `SubagentStart` | none | Starts an active subagent turn with the same visible behavior as `UserPromptSubmit`. |
| `SubagentStop` | none | If the payload matches the active session/turn, writes `done`, `Done`, and clears `startedAt`. |

## Active Turn Guard

Tool and stop events must match the active state file before they can overwrite it:

- `session_id` must match `activeSessionId`.
- When both the incoming payload and the state file have a turn id, `turn_id` must match `activeTurnId`.
- Mismatched background tool events are ignored.

This is the Phase 1 protection against Codex Desktop or internal events overwriting the visible user turn.

## Replay Verification

Fixtures live in:

```text
fixtures/hook-events/*.json
```

Run all fixtures:

```bash
node scripts/replay-hook-fixtures.js
```

Run one fixture:

```bash
node scripts/replay-hook-fixtures.js main-turn.json
```

The replay script creates an isolated temporary `CODEX_STATUSBAR_DIR`, invokes `scripts/codex-status-writer.js` once per fixture step, and validates the resulting `state.json`.

## Current Fixtures

| Fixture | Coverage |
|---|---|
| `main-turn.json` | `UserPromptSubmit` -> `PreToolUse` -> `PostToolUse` -> `PermissionRequest` -> `Stop`. |
| `ignored-background-event.json` | A background `PreToolUse` cannot overwrite the active turn. |
| `subagent-turn.json` | `SubagentStart` and `SubagentStop` produce visible state transitions. |
