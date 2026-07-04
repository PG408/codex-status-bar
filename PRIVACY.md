# Privacy

Codex Status Bar is local-first. It has no server component and does not send
status data to the project maintainer.

## Local Data Read By The App

| Path | Purpose |
|---|---|
| `~/.codex/statusbar/state.d/<session_id>.json` | Per-session display state written by this project's hooks. |
| `~/.codex/statusbar/state.json` | Legacy fallback display state when `state.d` is empty. |
| `~/.codex/session_index.jsonl` | Thread names shown in the Sessions menu. |
| `~/.codex/state_5.sqlite` | Best-effort archived-thread metadata for Codex Desktop sessions. |
| `~/.codex/hooks.json` | Hook installation and repair. |

## Local Data Written By The App

| Path | Purpose |
|---|---|
| `~/.codex/statusbar/state.d/<session_id>.json` | Display state for a Codex session. |
| `~/.codex/statusbar/app.log` | Local render log for diagnostics. |
| `~/.codex/statusbar/hooks-discovery.jsonl` | Debug-only hook schema log when `CODEX_STATUSBAR_DEBUG=1`. |
| `~/.codex/hooks.json` | Hook configuration updated by the installer or uninstaller. |

## Data Not Intentionally Stored Or Transmitted

Codex Status Bar does not intentionally store or transmit:

- prompts;
- model responses;
- command output;
- transcript contents;
- API keys or tokens;
- analytics events;
- telemetry to a remote server.

The optional hook discovery log records event names, payload keys, payload value
types, and selected safe identifiers. It is disabled unless
`CODEX_STATUSBAR_DEBUG=1`.

## Network Access

The current app does not perform update checks or other network requests.

## Hook Trust

Codex owns command hook trust and authorization. Codex Status Bar can install or
repair hook commands in `~/.codex/hooks.json`, but it cannot bypass Codex's hook
review flow and cannot reliably read Codex's private trust state.
