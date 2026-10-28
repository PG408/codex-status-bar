# Sessions Menu

The Sessions menu lists current Codex sessions from the `state.d` model. The
status bar still renders one lead session, selected by the same priority rule:

1. `permission`
2. `needs_input`
3. `tool`, `thinking`, or `compacting`
4. most recent `idle`, `done`, or `waiting`

The menu lists sessions from:

```text
~/.codex/statusbar/state.d/<session_id>.json
```

## Menu Sections

The menu keeps the session list prominent and groups secondary choices into native submenus:

- `Sessions`: active Codex sessions from `state.d`.
- `Show / Hide Codex`: toggles the Codex Desktop app from the menu or the recorded global shortcut.
- `Set Shortcut...` / `Change Shortcut...`: closes the menu and records a shortcut from the menu bar prompt without opening a settings window.
- Direct options: timer, status text, notification sounds, and `Hide Idle Sessions`.
- `Appearance`: chooses the Codex icon or an installed Codex Pet.
- `Diagnostics`: reveals the state directory or resets status.
- `About Codex Status Bar...`: opens the standard macOS About panel with version information.

## Session Rows

The Sessions section groups rows by `project`. A missing project is shown under `Other`. Each group header is a small secondary label aligned with the session title column and shows the number of visible sessions in that group.

Each session row is a custom AppKit view with:

- thread name from the latest matching `thread_name` in `~/.codex/session_index.jsonl`, truncated before it can overlap the timer or badge
- `Side Chat` when the session is a Codex Side Chat detected from local Codex Global State prompt history
- elapsed timer for `thinking`, `tool`, and `compacting`; `needs_input` has no timer
- `CLI` or `APP` badge when the surface is known; the badge uses the active color for running sessions and a muted color for resting sessions

If the thread name cannot be read and the session is not recognized as a Side
Chat, the row shows `Unknown`.

Timers use the main turn's `task_started.started_at` from the task transcript.
Compaction, repeated hooks, and child-agent activity keep that same origin.
The App also reads the matching task record directly, so an already-running
session with stale hook state is corrected without waiting for another hook.
Writers cache the matched record in `taskRecord`; a transcript-path change
triggers a new lookup, retaining the same turn's recorded origin if the new
file contains only continuation events. Completed records retain Codex's
`duration_ms`; idle and done rows still do not display a timer. When task
records are unavailable, legacy hook timing remains the fallback.

Run `node scripts/verify-task-timing-e2e.js [state-file]` to replay task timing
and compaction recovery in isolated state directories. The optional state
file supplies a real task transcript; its terminal events are removed only
in an isolated copy for recovery replay. Reports are saved under
`.tmp/task-timing-e2e/`.

Hover uses the system selection material so text, icons, and badges stay readable in light and dark menu appearances.

## Hide Idle Sessions

`Hide idle sessions` supports:

- 5 minutes
- 15 minutes
- 30 minutes
- 1 hour
- 12 hours
- 24 hours
- 7 days

This setting controls how long resting sessions remain visible in the menu. Session state files are retained independently for 7 days. Increasing the visibility window immediately restores retained sessions whose timestamps fall within the newly selected duration. When every retained session exceeds the selected duration, the Sessions section shows no active Codex sessions.

Side Chat rows use a shorter menu-only rule: after a Side Chat has been resting
for 5 minutes, it is hidden from the Sessions menu without deleting its state
file. A later hook event updates the retained session and makes it visible again.

## Click Focus

Clicking a session row attempts to focus the corresponding surface:

- Desktop rows open or focus `Codex.app` through bundle id `com.openai.codex`.
- Desktop rows with a URL focus target first open `codex://threads/<sessionId>` so active Codex Desktop threads can be focused directly.
- CLI rows map `TERM_PROGRAM` / `termProgram` to a terminal or editor app such as Terminal, iTerm, Warp, Ghostty, or Visual Studio Code.
- New state files prefer `focusTarget`; old state files fall back to `entrypoint`, `termProgram`, and Codex Desktop process detection.

The Desktop thread deeplink is best-effort. Active threads should open directly;
archived or missing threads may only bring Codex forward or show Codex's own
error. Exact terminal tab/window focus is not implemented because it requires a
separate terminal-specific focus target and Automation support.

Surface detection is produced by the shared hook resolver documented in `docs/hook-events.md`. Unknown rows remain visible, but click focus is intentionally a no-op when no reliable target is known.
