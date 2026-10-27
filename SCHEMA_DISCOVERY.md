# ORAH-F04 Schema Discovery Report

**Baseline Commit:** `5fd7edb81e7ff9ca3e46f4a36d1494b989467575`  
**Discovery Date:** 2026-10-27  
**Storage Model:** Scenario B — Checklist items serialized as JSON array within note payload

## Source Evidence
- **ChecklistItem model:** `lib/models/note.dart` lines 1–22 (`id`, `text`, `isDone`, `dueAt`)
- **Note serialization:** `lib/models/note.dart` lines 24–92 (`List<ChecklistItem> checklistItems` → JSON in `payload TEXT`)
- **SQLite schema v2:** `lib/data/database/orah_database.dart` lines 78–124, 192–250 (no dedicated task table)
- **Save path:** `lib/screens/note_editor_screen.dart` lines 443–498, 785–870 (autosave includes full checklist JSON)
- **DAO boundary:** `lib/data/database/note_dao.dart` lines 1–25 (whole-note read/write only)

## Decision: Sidecar Table Architecture
A dedicated `study_task_status` table will store study status independently of note payload to prevent race conditions between Kanban drags and editor autosaves.

**Migration:** Schema version 2 → 3  
**Table DDL:** See implementation commit following this discovery.

## Implementation Guardrails
- Do not add study status to `Note.toMap()` or `Note.fromMap()`.
- Do not change editor autosave debounce timing.
- Do not add network calls or cloud sync logic.
- Validate that the note and checklist task exist before accepting a status update.
- Keep study status writes independent from note payload writes.

## Persistence Validation Scope
The implementation stores study status in `study_task_status`, not in the serialized note payload. Tests cover database reopen, schema v2 upgrade, orphan cleanup, task/status validation, and concurrent status/note writes. The Kanban UI remains blocked until CI validates the branch head containing these tests.
