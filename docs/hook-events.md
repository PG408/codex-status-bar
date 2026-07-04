# Codex Hook Event Model

This document defines the Phase 2 multi-session state model. New hook writes go to one file per Codex session:

```text
~/.codex/statusbar/state.d/<session_id>.json
```

The Swift app reads `state.d/` and selects one lead session for the menu bar. During migration it can read the old `~/.codex/statusbar/state.json` as a fallback only when `state.d/` is empty. New project scripts should not write the legacy file.

## State Fields

Each session file contains display metadata and writer-owned status facts. Swift reads the
derived display fields; the writer uses `statusFacts` to aggregate main-thread and
subagent activity inside one session before deriving those fields.

| Field | Purpose |
|---|---|
| `state` | One of `idle`, `done`, `thinking`, `tool`, `compacting`, `permission`, or `waiting`. |
| `label` | Short menu bar label such as `Thinking`, `Running command`, or `Awaiting permission`. |
| `tool` | Raw tool name when available. |
| `threadName` | Latest matching `thread_name` from `~/.codex/session_index.jsonl`; defaults to `Unknown` when unavailable. |
| `project` | Basename of `cwd`, `working_directory`, or `current_working_directory`. |
| `sessionId` | Sanitized `session_id` or `sessionId`; also used as the state filename. |
| `turnId` | Sanitized `turn_id` or `turnId` for same-session stale event protection. |
| `pid` | Hook parent process id. |
| `entrypoint` | Normalized surface tag such as `cli`, `codex-desktop`, `manual`, `dev`, or `unknown`. |
| `entrypointSource` | Evidence used to resolve the surface: `payload`, `env`, `termProgram`, `process`, `previous`, or `unknown`. |
| `termProgram` | Terminal/editor environment value for CLI sessions, such as `Apple_Terminal`, `iTerm.app`, `WarpTerminal`, `vscode`, or `ghostty`. |
| `focusTarget` | Click-focus target. Desktop sessions use `{ "kind": "url", "url": "codex://threads/<sessionId>", "fallback": { "kind": "bundle", "bundleId": "com.openai.codex" } }`; CLI sessions use `{ "kind": "app", "appName": "..." }`; unknown sessions use `{ "kind": "none" }`. |
| `transcript` | Optional transcript path from `transcript_path`; used only to detect user interruption recovery markers. |
| `started` | `false` for lifecycle-created idle sessions; `true` after visible activity. |
| `startedAt` | Unix timestamp seconds for timer display; `0` when no timer should be shown. |
| `ts` | Unix timestamp seconds, with millisecond precision, when the session state was written. |
| `visibleUntilMs` | Writer compatibility field for short tool visibility. Swift no longer uses it to downgrade a running tool to `thinking`. |
| `minVisibleUntilMs` | Optional lower bound for tool or permission visibility. |
| `activity` | Optional visible activity owner. `subagent` means the current derived display came from subagent activity. |
| `statusFacts` | Writer-owned internal facts for the session, currently `main` plus `subagents`. This is not a Swift UI contract beyond being safe to ignore. |

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
| `scripts/codex-lifecycle-writer.js` | `SessionStart`, `SessionEnd` | Create a session file or mark an existing session complete. |
| `scripts/codex-status-writer.js` | `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PreCompact`, `PostCompact`, `PermissionRequest`, `Stop`, `SubagentStart`, `SubagentStop` | Update the corresponding session file for visible status changes. |

After a successful `SessionStart` or visible activity write, the writer asks the shared hook manager to launch `CodexStatusBar.app` if it is not already running. This is the recovery path after crash, force quit, or automatic exit.

## Event Transitions

| Event | Matcher | Writer behavior |
|---|---:|---|
| `SessionStart` | none | Creates `idle` session state with `started: false`. |
| `SessionEnd` | none | Marks an existing session `done`, clears active turn metadata, and lets the menu retention setting decide when it disappears. |
| `UserPromptSubmit` | none | Updates main `thinking`, `Thinking`, a non-zero `startedAt`, `started: true`, and the incoming main `turnId`. During a subagent payload, updates that subagent as running instead. |
| `PreToolUse` | `*` | If the payload matches the main active `turnId`, updates main `tool` and maps the tool name to a short label. Unknown tools use `Using tool`. During a subagent payload, updates that subagent as running without overriding a higher-priority main tool. |
| `PostToolUse` | `*` | If the payload matches the main active `turnId`, returns main to `thinking` and preserves the timer. During a subagent payload, keeps that subagent running. |
| `PreCompact` | none | If the payload matches the main active `turnId`, updates main `compacting`, `Compacting`, and preserves the active timer. During a subagent payload, keeps that subagent running. |
| `PostCompact` | none | If the payload matches the main active `turnId`, returns main to `thinking` and preserves the timer. During a subagent payload, keeps that subagent running. |
| `PermissionRequest` | `*` | Updates main or subagent permission. Main permission displays `Awaiting permission`; subagent permission displays `Subagent awaiting permission`. |
| `Stop` | none | If the payload matches the main active `turnId`, updates main `done`, clears active main metadata, and derives session-level `done`. |
| `SubagentStart` | none | Adds or updates the corresponding subagent as running. |
| `SubagentStop` | none | Removes the corresponding subagent from active facts. It does not write session-level `done`; the session display is re-derived from remaining main and subagent facts. |

A subagent payload is any payload that carries `agent_id` or `agent_type`. This covers the real Codex subagent sequence where `SubagentStart` is immediately followed by a subagent-scoped `UserPromptSubmit` and tool events in the same `session_id`.

## Same-Session Turn Guard

Main-thread tool and stop events must match the target session file before they can update main facts:

- The file path is selected by `session_id`.
- When both the incoming payload and existing session file have a main turn id, `turn_id` must match the file's main `turnId`.
- Old events from the same session are ignored when their turn id does not match.
- Events from other sessions write only their own session file and cannot overwrite another session file.

Subagent events are keyed by `agent_id` when present, otherwise by their `turn_id`.
`SubagentStop` affects only that subagent fact. This keeps the main turn able to
accept later `PostToolUse` or `Stop` events after a subagent completes.

## Single-Session State Aggregation

Within one session, the writer derives `state`, `label`, `tool`, and `activity` from
internal facts in this order:

1. main or subagent permission
2. main tool
3. main compacting
4. subagent running
5. main thinking
6. waiting
7. done
8. idle

This priority is local to one session. It does not change Swift's cross-session lead
selection rule.

## Lead Session Selection

The Swift app aggregates all files in `state.d/` and renders one lead session in the menu bar:

1. `permission`
2. `tool`, `thinking`, or `compacting`
3. `idle`, `done`, or `waiting`

Within the same priority tier, the most recent `ts` wins.

A live main `thinking` or `compacting` session remains active until a matching `PostCompact` or main `Stop` updates main facts, `SessionEnd` marks the file complete, Swift detects a transcript `turn_aborted` event with `reason: "interrupted"`, or Swift determines that the owning surface is no longer alive. `SubagentStop` only removes subagent activity. A live main `tool` session remains `tool` until `PostToolUse`; after three minutes from `PreToolUse`, Swift changes only the icon tint as a warning and leaves the persisted state, label, and timer semantics unchanged.

For liveness, CLI sessions may use the hook parent pid as supporting evidence. Desktop sessions do not use the Codex app pid to prove an individual session is still active, because the Desktop app process can outlive any one conversation. `SessionEnd` is the normal deletion path; Codex Desktop process exit is only a cleanup signal for Desktop session files.

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

Hook install/repair and hook-launched app behavior are verified by:

```bash
node scripts/verify-hook-manager.js
```

## Current Fixtures

| Fixture | Coverage |
|---|---|
| `two-cli-sessions.json` | Two CLI sessions exist in parallel; permission outranks tool/thinking. |
| `cli-desktop-parallel.json` | CLI and desktop sessions coexist; desktop permission request becomes lead and lifecycle end removes the file. |
| `stale-background-cannot-win.json` | Old same-session tool events and background sessions cannot displace a permission lead. |
| `subagent-session.json` | `SubagentStart`, subagent-scoped prompt/tool/compact events, subagent permission, and `SubagentStop` update the corresponding session facts while keeping only the two Subagent labels visible. |
| `subagent-main-stop-session.json` | Main `Stop` is the only session-level done signal and clears active subagent facts. |
| `subagent-priority-session.json` | Single-session aggregation keeps main thinking/tool/compacting authoritative according to local priority, keeps subagent permission highest, and accepts later main `PostToolUse` / `Stop` after `SubagentStop`. |
| `compacting-session.json` | `PreCompact` shows context compaction as `compacting`, then `PostCompact` returns to `thinking`. |
| `transcript-path-session.json` | Writer preserves `transcript_path` across subsequent events for interruption recovery. |
