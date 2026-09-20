# Attack 15 — Proper Checklist Engine

NOVA Notes now uses structured checklist items instead of treating a checklist as plain text.

## Included
- Individual task objects with stable IDs.
- Persistent checked/unchecked state.
- Add, edit, delete and drag/reorder tasks.
- Completed tasks use strike-through styling.
- Progress bar and completed/total count.
- Legacy checklist text is migrated when a note is opened.
- Search indexes checklist item text.
- TXT, Markdown, PDF and Excel exports preserve completion state.
- Existing note metadata remains preserved.

## Compatibility
The legacy `content` field remains synchronized as `[x]` / `[ ]` lines so older backups and search/export flows remain readable.

## Validation
Source changes are committed to the Attack 15 branch. Local Flutter analyzer/tests remain pending until the Flutter SDK is installed on the development PC.
