# ORAH Feature Preservation Registry

Status: preservation gate implementation in progress; critical note journeys now have dedicated widget tests.
Production target: `main`
Comparison baseline: `orah-base-v1`
Audit branch: `integration/feature-preservation-main`
Last audited: 2026-11-14 (post-PR #143 merge)

## Status definitions

- **Present (source):** implementation or UI entry point was found in the inspected branch.
- **Missing (source):** expected UI/implementation was not found in the inspected file.
- **Needs runtime test:** source exists, but end-to-end behavior has not been verified.
- **Not audited:** no reliable source comparison has been completed yet.

Source presence is not proof that a feature works on a device.

## Confirmed findings

| Feature | `main` | `orah-base-v1` | Evidence / next action |
|---|---|---|---|
| Merge Notes action in note menu | Present (source) | Present (source) | Restored to `main` by PR #143; verify merge behavior with widget and repository regression tests. |
| Delete note to Trash from note menu | Present (source) | Present (source) | Main has “Move to Trash” action and repository save with `isTrashed: true`; verify UI behavior and undo/restore. |
| Trash screen | Present (source) | Present (source) | `lib/screens/trash_screen.dart` exists in both; add widget/regression coverage. |
| Note repository delete/save behavior | Present (source) | Present (source) | `lib/data/repositories/local_note_repository.dart`; audit semantic differences before reconciling. |
| Linked-note model support | Not yet confirmed | Present (source) | Compare `lib/models/note.dart`; check serialization, migrations, and UI dependencies before porting Merge Notes. |
| Note editor | Present (source) | Present (source) | Files differ substantially; do not replace main wholesale. Review feature-level diffs and regression tests. |
| Backup/restore | Not yet audited on main | In progress on feature branch | PR #142 remains open/draft and targets `orah-base-v1`; do not merge until it is rebased/retargeted safely and Vault portability, attachment round trips, rollback and full tests pass. |

## Post-merge production baseline

- `main` merge commit: `a03403e47e70c98d633bacf4cd519f19eb4a5a55` (PR #143).
- Post-merge workflow #1908: Analyze/Test passed; Debug APK passed.
- Merge Notes, Delete/Move to Trash, and this registry were confirmed present in the merged `main` source. Physical-device behavior remains to be tested.

## Current preservation automation

- Dedicated test suite: `test/screens/feature_preservation_test.dart`.
- CI step: `Feature preservation gate (critical note journeys)` in `.github/workflows/orah-android-build.yml`.
- This gate currently covers Merge Notes, Delete-to-Trash, and Trash restore. It is not yet a full UI audit of every feature in the backlog.

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
- [x] Widget tests for Merge Notes menu, merge confirmation/data combination, Delete-to-Trash, and Trash restore (`test/screens/feature_preservation_test.dart`).
- [x] Dedicated CI step runs the critical feature-preservation widget suite on every Android build workflow run.
- [ ] Expand widget coverage to all remaining critical menus and journeys listed above.
- [ ] Release APK smoke test against the exact commit intended for production.
