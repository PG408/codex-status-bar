# Archive Chat Handling

Codex Status Bar treats `state.d/<session_id>.json` as the runtime status source. Hook events write active states such as `thinking`, `tool`, `permission`, `compacting`, and `done`.

Archiving a Codex Desktop chat is different: it is thread metadata, not a runtime hook event. A chat can be archived without a `Stop` or `SessionEnd` hook reaching the status bar. When that happens, the session state file can remain stuck in an active state even though the thread has been removed from Codex's active list.

## Source

The archive state comes from Codex's local thread metadata database:

```text
~/.codex/state_5.sqlite
```

Only the `threads` table is read, and only these fields are needed:

```sql
select id, archived, archived_at
from threads
where id in (...)
```

`threads.id` is the primary key, so lookup by current status-bar session ids uses the SQLite primary-key index. The status bar does not scan the full table.

## Runtime Flow

On each existing status-bar tick:

1. Load `state.d` session files as before.
2. Read `threads.archived` for the current session ids when the SQLite file mtime or session id set changes.
3. Apply archive overlay:
   - archived sessions do not participate in lead-session selection.
   - archived sessions do not appear in the Sessions menu.
   - if an archived session file is still active, rewrite it to `done` so undo archive cannot resurrect a fake running state.

The overlay is best-effort. If SQLite is missing, locked, unreadable, or the table is unavailable, Codex Status Bar falls back to the existing `state.d` behavior.

## Undo Archive

The state file is retained for up to 7 days when a thread is archived. This preserves enough local display state for undo during the retention window:

```text
archive:
  archived = 1
  state file retained for up to 7 days
  active state rewritten to done
  hidden from lead/menu

undo archive:
  archived = 0
  state file still exists
  session may reappear as done/resting
```

Visibility after undo continues to use `Hide idle sessions`. Undo after the 7-day state retention window cannot restore a state file that has already been cleaned up.

## Boundaries

This overlay does not replace hook state. It does not infer `thinking`, `tool`, `permission`, or `compacting` from SQLite. It also does not use SQLite titles or rollout paths for display; those can be considered separately if needed.
