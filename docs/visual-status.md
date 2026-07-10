# Visual Status Reference

This document records the current Codex Status Bar visual contract. It is a
reference for status text, icon tint, timer behavior, and menu row presentation.
Runtime event semantics remain defined in `docs/hook-events.md`.

## Menu Bar Status

The menu bar renders the current lead session selected by the cross-session
priority rule. The displayed label comes from the session file when present,
with the fallback labels below.

| Display case | Effective state | Fallback label | Timer | Codex icon color | Special icon behavior | Main trigger |
|---|---|---:|---:|---|---|---|
| Idle | `idle` | none | no | white | image-only status item | Lifecycle-created session, reset, or inactive fallback. |
| Done | `done` | none | no | white | image-only status item | Main `Stop`, `SessionEnd`, archived active session settlement, or manual reset. |
| Thinking | `thinking` | `Thinking` | yes | green | standard Codex icon | Main `UserPromptSubmit`, `PostToolUse`, or `PostCompact`. |
| Tool | `tool` | `Using tool` | yes | light blue | standard Codex icon | Main `PreToolUse`; known tools replace the fallback label with mapped text such as `Running cmd` or `Editing`. |
| Long-running tool warning | `tool` | current tool label | yes | amber | standard Codex icon with warning tint only | A `tool` session has no `PostToolUse` after 3 minutes. The state, label, and timer are not changed. |
| Compacting | `compacting` | `Compacting` | yes | yellow | standard Codex icon | Main `PreCompact`. |
| Permission | `permission` | `Awaiting permission` | no | red | Codex icon plus red status dot | Main `PermissionRequest`. |
| Waiting | `waiting` | `Waiting` | no | yellow | standard Codex icon | Stale active Desktop session fallback after the liveness rule marks it waiting. |
| Subagent running | `thinking` | `Subagent` | yes | green | standard Codex icon | `SubagentStart` or subagent-scoped activity while no higher-priority main activity is visible. |
| Subagent permission | `permission` | `Subagent permission` | no | red | Codex icon plus red status dot | Subagent-scoped `PermissionRequest`. |

Color constants in the current Swift implementation:

| Name | sRGB |
|---|---|
| green | `0.08, 0.72, 0.48` |
| white | system white |
| light blue | `0.38, 0.68, 1.0` |
| yellow | `1.0, 0.78, 0.18` |
| red | `1.0, 0.23, 0.20` |
| amber warning | `0.95, 0.70, 0.16` |

## Icon Modes

`Codex` icon style uses the bundled original Codex menu bar template and applies
the state colors above. `permission` also uses the status-dot overlay so approval
requests remain visually distinct.

`Pet` icon style is intentionally separate. PET rendering follows the PET icon
frames and does not use the Codex tint table. State text and timers are still
derived from the same session state.

## Menu Row Status

The Sessions menu does not duplicate the menu bar state icon in front of each
session. Instead, it combines surface identity and activity in the `APP` or
`CLI` badge.

| Row element | Rule |
|---|---|
| Project group | Uses `project`; missing projects are grouped under `Other`. |
| Session title | Uses latest `thread_name` from `~/.codex/session_index.jsonl`; Side Chat sessions display `Side Chat`; fallback is `Unknown`. |
| Timer | Shown for `thinking`, `tool`, and `compacting` when `startedAt > 0`. |
| Badge text | `APP` for Desktop focus targets, `CLI` for terminal/editor focus targets. |
| Running badge | Uses the system accent color for `thinking`, `tool`, and `compacting`. |
| Resting badge | Uses a muted system fill for `idle`, `done`, `waiting`, and permission rows. |
| Hover | Uses system selection colors so title, timer, and badge remain readable. |

## Notification Sounds

When notification sounds are enabled:

| State transition | Sound |
|---|---|
| Enter `permission` | `Ping` |
| Enter `done` | `Glass` |
| Other states | none |

## Boundaries

This visual contract does not define hook authorization status. The app can
verify hook configuration and observe whether hooks have run, but it cannot
reliably read Codex's private trust state for command hooks.
