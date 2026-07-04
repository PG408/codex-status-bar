# Sessions Menu

The Sessions menu lists current Codex sessions from the `state.d` model. The
status bar still renders one lead session, selected by the same priority rule:

1. `permission`
2. `tool`, `thinking`, or `compacting`
3. most recent `idle`, `done`, or `waiting`

The menu lists sessions from:

```text
~/.codex/statusbar/state.d/<session_id>.json
```

## Menu Sections

The menu is grouped into four sections:

- `Sessions`: active Codex sessions from `state.d`.
- `Options`: timer, status text, notification sounds, and `Hide idle sessions`.
- `Icon`: system color, Codex icon, and Codex Pets.
- `Diagnostics`: reveal state directory, reset status, and quit.

## Session Rows

The Sessions section groups rows by `project`. A missing project is shown under `Other`. Each group header is a small secondary label aligned with the session title column and shows the number of visible sessions in that group.

Each session row is a custom AppKit view with:

- thread name from the latest matching `thread_name` in `~/.codex/session_index.jsonl`, truncated before it can overlap the timer or badge
- `Side Chat` when the session is a Codex Side Chat detected from local Codex Global State prompt history
- elapsed timer for `thinking`, `tool`, and `compacting`
- `CLI` or `APP` badge when the surface is known; the badge uses the active color for running sessions and a muted color for resting sessions

If the thread name cannot be read and the session is not recognized as a Side
Chat, the row shows `Unknown`.

Hover uses the system selection material so text, icons, and badges stay readable in light and dark menu appearances.

## Hide Idle Sessions

`Hide idle sessions` supports:

- 5 minutes
- 15 minutes
- 30 minutes
- 1 hour
- Never

This setting controls how long resting sessions remain visible in the menu. The same duration is also used as the cleanup window for completed or idle display records. If every row would be hidden before cleanup runs, the most relevant remaining session is still shown so the Sessions section is not empty while state exists.

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
