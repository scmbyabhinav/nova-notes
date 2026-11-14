# ORAH Feature Preservation Registry

Status: initial source audit; not a complete runtime verification.
Production target: `main`
Comparison baseline: `orah-base-v1`
Audit branch: `integration/feature-preservation-main`
Last audited: 2026-11-14

## Status definitions

- **Present (source):** implementation or UI entry point was found in the inspected branch.
- **Missing (source):** expected UI/implementation was not found in the inspected file.
- **Needs runtime test:** source exists, but end-to-end behavior has not been verified.
- **Not audited:** no reliable source comparison has been completed yet.

Source presence is not proof that a feature works on a device.

## Confirmed findings

| Feature | `main` | `orah-base-v1` | Evidence / next action |
|---|---|---|---|
| Merge Notes action in note menu | Missing | Present (source) | `lib/screens/home_screen.dart`: baseline contains menu entry, switch action, and `_mergeNoteWithAnother`; main inspected version does not. Restore with dependencies and tests. |
| Delete note to Trash from note menu | Present (source) | Present (source) | Main has “Move to Trash” action and repository save with `isTrashed: true`; verify UI behavior and undo/restore. |
| Trash screen | Present (source) | Present (source) | `lib/screens/trash_screen.dart` exists in both; add widget/regression coverage. |
| Note repository delete/save behavior | Present (source) | Present (source) | `lib/data/repositories/local_note_repository.dart`; audit semantic differences before reconciling. |
| Linked-note model support | Not yet confirmed | Present (source) | Compare `lib/models/note.dart`; check serialization, migrations, and UI dependencies before porting Merge Notes. |
| Note editor | Present (source) | Present (source) | Files differ substantially; do not replace main wholesale. Review feature-level diffs and regression tests. |
| Backup/restore | Not audited on main | In progress on feature branch | Keep PR #142 unmerged until Vault portability, attachment round trips, rollback and full tests pass. |

## Mandatory preservation gate

Before a feature PR can be merged into `main`:

1. Identify the user-visible entry point and implementation.
2. Add or update a regression test for the feature.
3. Verify related persistence, migrations, localization, reminders, and navigation.
4. Run formatting, static analysis, full tests, and required Android build jobs.
5. Confirm no unrelated feature or entitlement was removed or hidden.
6. Record the tested commit SHA and CI run in this registry.

## Reconciliation rules

- `main` remains the production source of truth until an approved PR is merged.
- Never force-push or replace a whole screen merely to recover one action.
- Port feature changes in dependency groups; preserve newer `main` behavior.
- Do not merge a branch solely because its latest APK build is green.
- Keep draft PRs open until the complete diff and all required checks are reviewed.
- No feature removal, hiding, paywall change, or entitlement change without explicit product approval.

## Audit backlog

- [ ] Full inventory of note creation, editing, autosave, search, sort, filters, pin, favorite, archive, delete, trash, restore, duplicate, merge, link, and version history.
- [ ] Folders, tags, checklist, reminders, calendar, focus sessions, statistics, and Kanban.
- [ ] Attachments, image handling, import, export, sharing, and email attachment flow.
- [ ] Vault, PIN/app lock, biometric unlock, encryption, portable backup, and restore.
- [ ] Premium/free entitlements, purchase flows, subscription/lifetime visibility, and paywall behavior.
- [ ] Accessibility, localization, Android shortcuts, notifications, and deep links.
- [ ] Widget tests for critical menus and user journeys.
- [ ] Release APK smoke test against the exact commit intended for production.
