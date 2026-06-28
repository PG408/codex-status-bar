# Codex Hook Event Model

This document defines the Phase 2 multi-session state model. New hook writes go to one file per Codex session:

```text
~/.codex/statusbar/state.d/<session_id>.json
```

The Swift app reads `state.d/` and selects one lead session for the menu bar. During migration it can read the old `~/.codex/statusbar/state.json` as a fallback only when `state.d/` is empty. New project scripts should not write the legacy file.

## State Fields

Each session file contains display metadata only:

| Field | Purpose |
|---|---|
| `state` | One of `idle`, `done`, `thinking`, `tool`, `permission`, or `waiting`. |
| `label` | Short menu bar label such as `Codex thinking`, `Running command`, or `Awaiting permission`. |
| `tool` | Raw tool name when available. |
| `project` | Basename of `cwd`, `working_directory`, or `current_working_directory`. |
| `sessionId` | Sanitized `session_id` or `sessionId`; also used as the state filename. |
| `turnId` | Sanitized `turn_id` or `turnId` for same-session stale event protection. |
| `pid` | Hook parent process id. |
| `entrypoint` | Normalized surface tag such as `cli`, `codex-desktop`, `manual`, `dev`, or `unknown`. |
| `entrypointSource` | Evidence used to resolve the surface: `payload`, `env`, `termProgram`, `process`, `previous`, or `unknown`. |
| `termProgram` | Terminal/editor environment value for CLI sessions, such as `Apple_Terminal`, `iTerm.app`, `WarpTerminal`, `vscode`, or `ghostty`. |
| `focusTarget` | Click-focus target. Desktop sessions use `{ "kind": "bundle", "bundleId": "com.openai.codex" }`; CLI sessions use `{ "kind": "app", "appName": "..." }`; unknown sessions use `{ "kind": "none" }`. |
| `started` | `false` for lifecycle-created idle sessions; `true` after visible activity. |
| `startedAt` | Unix timestamp seconds for timer display; `0` when no timer should be shown. |
| `ts` | Unix timestamp seconds, with millisecond precision, when the session state was written. |
| `visibleUntilMs` | Optional upper bound for a short tool label. |
| `minVisibleUntilMs` | Optional lower bound for tool or permission visibility. |

The writer does not store prompts, command output, transcript contents, or secrets.

## Surface Resolution

Both writers use the same surface resolver. Resolution order is:

1. explicit payload fields: `entrypoint`, `entry_point`, `term_program`, or `termProgram`
2. explicit environment override: `CODEX_STATUSBAR_ENTRYPOINT` or `CODEX_ENTRYPOINT`
3. terminal environment: `TERM_PROGRAM` implies `entrypoint: "cli"`
4. process evidence: a hook parent process under `Codex.app` implies `entrypoint: "codex-desktop"`
5. previous state for the same session
6. `unknown`

This keeps CLI sessions working through terminal environment inheritance while allowing Codex Desktop sessions to be identified when the hook payload does not include an entrypoint.

## Writer Split

Two hook writers are installed:

| Script | Events | Responsibility |
|---|---|---|
| `scripts/codex-lifecycle-writer.js` | `SessionStart`, `SessionEnd` | Create or delete a session file. |
| `scripts/codex-status-writer.js` | `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PermissionRequest`, `Stop`, `SubagentStart`, `SubagentStop` | Update the corresponding session file for visible status changes. |

## Event Transitions

| Event | Matcher | Writer behavior |
|---|---:|---|
| `SessionStart` | none | Creates `idle` session state with `started: false`. |
| `SessionEnd` | none | Deletes that session's state file. |
| `UserPromptSubmit` | none | Writes `thinking`, `Codex thinking`, a non-zero `startedAt`, `started: true`, and the incoming `turnId`. |
| `PreToolUse` | `*` | If the payload matches that session's active `turnId`, writes `tool` and maps the tool name to a short label. |
| `PostToolUse` | `*` | If the payload matches that session's active `turnId`, returns to `thinking` and preserves the timer. |
| `PermissionRequest` | `*` | Writes `permission`, `Awaiting permission`, `started: true`, and clears `startedAt`. |
| `Stop` | none | If the payload matches that session's active `turnId`, writes `done`, `Done`, and clears `startedAt`. |
| `SubagentStart` | none | Starts a visible subagent turn with the same behavior as `UserPromptSubmit`. |
| `SubagentStop` | none | If the payload matches that session's active `turnId`, writes `done`, `Done`, and clears `startedAt`. |

## Same-Session Turn Guard

Tool and stop events must match the target session file before they can overwrite it:

- The file path is selected by `session_id`.
- When both the incoming payload and existing session file have a turn id, `turn_id` must match the file's `turnId`.
- Old events from the same session are ignored when their turn id does not match.
- Events from other sessions write only their own session file and cannot overwrite another session file.

## Lead Session Selection

The Swift app aggregates all files in `state.d/` and renders one lead session in the menu bar:

1. `permission`
2. `tool` or `thinking`
3. `idle`, `done`, or `waiting`

Within the same priority tier, the most recent `ts` wins.

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
node scripts/replay-hook-fixtures.js two-cli-sessions.json
```

The replay script creates an isolated temporary `CODEX_STATUSBAR_DIR`, invokes the lifecycle or status writer for each fixture step, verifies `state.d/`, rejects legacy `state.json` writes, and checks the expected lead session.

## Current Fixtures

| Fixture | Coverage |
|---|---|
| `two-cli-sessions.json` | Two CLI sessions exist in parallel; permission outranks tool/thinking. |
| `cli-desktop-parallel.json` | CLI and desktop sessions coexist; desktop permission request becomes lead and lifecycle end removes the file. |
| `stale-background-cannot-win.json` | Old same-session tool events and background sessions cannot displace a permission lead. |
| `subagent-session.json` | `SubagentStart` and `SubagentStop` update the corresponding session file. |
