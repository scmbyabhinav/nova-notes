# Kanban Goals — Design Note

Status: implementation in progress on `feature/kanban-goals`; PR #111 remains draft pending CI and final regression review.

## Baseline and branch
- Repository: `scmbyabhinav/nova-notes`
- Feature branch: `feature/kanban-goals`
- Base commit: `c17a794932392fc0dc7b7a905b487753f32b6757` (validated SQLite foundation)
- PR #109 is still open as a draft against `main`; the feature branch is intentionally based on the latest `integration/sqlite-foundation` head instead of assuming #109 has merged.
- Keep this feature isolated from the SQLite foundation/migration PR. Do not modify unrelated workflows, note persistence, or migration behavior except for the additive schema migration needed by Kanban.

## Proposed data model
Add one additive SQLite migration with:
- `kanban_cards`: UUID id, title, description, status (todo/in_progress/done), priority, optional due date/color/label/checklist JSON, optional goal id, sort order, timestamps, and soft-delete timestamp.
- `goals`: UUID id, title, description, optional target date, timestamps, and soft-delete timestamp.
- `links`: UUID id, source type/id, target type/id, link kind, timestamps, soft-delete timestamp. Use for card↔goal, card↔note, card↔card (related/blocks/blocked-by), and goal↔note. Validate target availability at read time so deleted/trashed targets render as unavailable.
- `time_entries`: UUID id, card id, UTC started-at and optional ended-at timestamps. Sum sessions for card/goal/today totals. Derive elapsed time from persisted timestamps rather than relying on a ticking counter.

Use foreign-key behavior and indexes consistent with the existing database conventions; avoid destructive cascades that would erase recoverable links/history. A migration test must upgrade a pre-Kanban database containing notes and verify the notes remain unchanged.

## Screens and navigation
1. Kanban workspace: three statuses (To Do, In Progress, Done), counts, empty states, card create/edit/detail, drag/reorder, quick-move actions, and undo feedback.
2. Phone layout: swipeable columns; tablet layout: all columns side by side.
3. Goals list: progress is Done cards / all non-deleted cards for that goal. Opening a goal shows its board with all three columns visible and filtered to that goal.
4. Main board toggle: All cards / By goal.
5. Link pickers and chips: note search sheet, goal/card linking, and graceful unavailable state for trashed targets.
6. Card timers: start/pause/stop; one active timer by default; starting a second pauses the first; moving a card to Done stops its timer. Notifications are optional and must request permission only on first timer start.
7. Home entry: preserve the current ORAH logo/icon tap behavior and add Kanban to its existing menu/sheet. Add an Android app shortcut alongside existing quick actions without removing current actions.
8. Folders integration (user clarification): expose a Kanban entry/collection from Folders so users can find the Kanban workspace and its cards alongside their organization workflow. Completed boards/cards can be archived or soft-deleted; use Trash/recovery where supported. Assumption: there is one main Kanban workspace plus goal-filtered boards, not a separate independent board for every goal.

## Confirmed entitlements
- Free: basic Kanban board, add/edit/move/reorder/delete cards, three columns.
- Pro: goals, note/card links, per-card timers and time summaries.
- Confirmed archive policy: archive completed boards/cards by default; provide a separate permanent-delete action.
- The feature catalog and gate tests include Pro gates for goals, links, and timers.

## Quality gates
- All user-facing strings in English ARB and corresponding Chinese ARB keys.
- DAO/repository tests with isolated SQLite databases; old-schema migration/data-preservation test; timer math/restart/single-active/Done-stop tests; widget tests for movement, goal columns, and link navigation.
- Keep Android target/compile SDK at 36 and existing CI workflows intact.
- Run formatting, `flutter analyze`, full tests, and required Android build jobs. Do not hide failures or weaken assertions.

## Small implementation commits
- [x] Additive schema and migration tests.
- [x] DAO/repository streams and isolated repository tests.
- [x] Board/goals UI, navigation, localization, and initial widget tests.
- [x] Timer persistence, policy, summaries, and timer tests.
- [x] Linking, note-editor backlinks, entitlement catalog/gate tests, and Android shortcut.
- [ ] Full CI validation, on-device review, and any required fixes.

## Remaining implementation checks
- Finish link UX for all supported link types and note-editor backlinks.
- Add timer settings/summary UI and verify elapsed-time behavior across restarts.
- Add and run the complete migration, repository, timer, and widget test suite; fix all CI failures before moving the PR out of draft.
