# Attack 19 — Portable Backup 2.0

NOVA can now create a `.nova` package containing notes, folders, and actual attachment binaries. Restore extracts attachments and merges notes by stable ID using the existing newer-note-wins logic.

Settings exposes Create backup and Restore backup actions using native file/share surfaces.

Validation remains pending until Flutter is installed locally; native picker/share behavior still needs device testing.
