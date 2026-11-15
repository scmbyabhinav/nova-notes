# ORAH Full Feature Inventory — Main Branch

Audit commit: `df238e47f98dbf83fcd6b51b42c90a831bd4dde6` (PR #144 merge)
Audit date: 2026-11-15
Scope: static source and existing automated-test inventory on `main`.
Important: **Source present is not the same as end-to-end verified.** This document does not claim physical-device acceptance.

## Status legend

- **Source present** — UI/service/model implementation was located in the audited main-branch source.
- **Existing automated coverage** — a relevant test file exists; exact scenario coverage must still be checked.
- **Not verified** — no dedicated end-to-end test evidence or physical-device evidence was confirmed in this audit.
- **In development / planned** — the in-app feature catalogue explicitly labels it that way.

## A. Capture and note lifecycle

| Feature | Source evidence | Test evidence / status |
|---|---|---|
| Quick Capture / new note | Home shell and note editor entry points in `lib/app.dart` | Existing widget/repository tests; exact full journey not yet confirmed |
| Checklist capture | Home capture sheet and checklist note model/editor | Not verified end-to-end |
| Voice capture | `VoiceSpeechService`, editor integration, `speech_to_text_test.dart` | Service tests exist; device microphone/recognition not verified here |
| Share to ORAH / intake | Share-intake service and inbox-related home flows | Not verified end-to-end |
| Document scanner | Advertised in `orah_features_screen.dart` as Android feature | Runtime implementation/device path needs explicit verification |
| OCR | Advertised in feature catalogue | Runtime implementation/device path needs explicit verification |
| Edit and autosave | `note_editor_screen.dart`, `LocalNoteRepository.saveNote` | Repository stream/concurrent mutation tests exist; full editor journey not verified |
| Duplicate note | Home note action menu | Not independently covered by preservation suite |
| Merge notes | Home menu and `_mergeNoteWithAnother` | Preservation widget test verifies menu, merged content and source removal after confirmation |
| Delete to Trash | Home action saves note with trashed state | Preservation widget test verifies note is trashed and content remains |
| Undo delete | Undo snackbar/action exists in home implementation | **Not covered** by current preservation suite |
| Restore from Trash | `TrashScreen` | Preservation widget test verifies restore |
| Permanently delete / empty Trash | Trash screen actions | Not verified by dedicated preservation test |
| Archive / unarchive | Home actions and archived screen | Not independently tested in preservation suite |
| Pin / favorite | Home actions, note model and search filters | Repository/model tests exist; UI journey not verified |
| Note version history | Repository stores snapshots; version history screen | `note_version_history_test.dart` exists; UI restore journey needs verification |

## B. Organization and discovery

| Feature | Source evidence | Test evidence / status |
|---|---|---|
| Folders | Folders screen and folder repository | No dedicated end-to-end test confirmed in this audit |
| Tags | Note model, editor and search filters | `note_tag_filter_test.dart` exists |
| Search | Search screen, repository FTS/fallback search | `orah_universal_search_index_test.dart` and repository tests exist; UI coverage incomplete |
| Advanced search operators | Search screen and feature gate | Not all operators covered by UI tests |
| Search filters / quick chips | Search screen | Not fully verified |
| Sort modes | Home/search flows | Not fully verified |
| Linked notes | Note model, search index and Kanban links | `linked_notes_model_test.dart` exists; complete navigation/link lifecycle not verified |
| Triage Inbox | Share-intake and home flow references | Needs end-to-end audit |

## C. Writing and content

| Feature | Source evidence | Test evidence / status |
|---|---|---|
| Text notes | Note editor and repository | Existing repository/widget tests |
| Checklists and due dates | ChecklistItem model and editor | No complete editor journey verified |
| Images and attachments | Note model, attachment services and editor | Backup attachment round-trip still requires separate verification |
| Templates | Templates screen | Dedicated functional coverage not confirmed |
| Slash commands | Feature catalogue labels this **In development** | Do not advertise as complete |
| Version history | Repository and history sheet | Repository test exists; restore UI not verified |

## D. Productivity

| Feature | Source evidence | Test evidence / status |
|---|---|---|
| Reminders | Reminder service and editor/home flows | Scheduling/cancel/permission device tests needed |
| Calendar | Calendar and calendar history screens | No dedicated UI test confirmed |
| Deadline countdown | Feature catalogue and due-date model | Exact behavior needs test |
| Kanban boards | Kanban screen/repository/database | `kanban_repository_test.dart`, migration and screen tests exist |
| Kanban goals, links and timers | Goals screen and Kanban repository | Repository tests exist; all user journeys not verified |
| Pomodoro / focus timer | Pomodoro screen and focus session service | `focus_session_service_test.dart`; lifecycle/device behavior needs test |
| Daily Reflection | Reflection screen, prompt and scheduling logic | `prompt_service_test.dart`; scheduled presentation needs device test |
| Statistics / writing insights | Statistics screen and streak service | `streak_service_test.dart`; metric correctness and UI need verification |

## E. Security and privacy

| Feature | Source evidence | Test evidence / status |
|---|---|---|
| Private Vault | Vault screen, repository encrypted record storage, security service | Dedicated Vault portability tests exist on backup branch; main-branch full security journey not yet confirmed |
| Vault folders | Vault screen and preferences | Needs dedicated persistence tests |
| Vault PIN / authentication | Vault and security services | Needs dedicated lifecycle/security regression tests |
| App lock / biometrics | App-lock and security settings screens | Device biometric tests required |
| Vault auto-lock | Settings and Vault preference | Needs timer/lifecycle tests |
| Local-first storage | SQLite repository and SharedPreferences | Database/repository tests exist; offline device acceptance pending |
| Forgotten-PIN reset warning | Settings explicitly warns that reset permanently destroys Vault contents | Verify warning and destructive confirmation on device |

## F. Backup, export and sharing

| Feature | Source evidence | Test evidence / status |
|---|---|---|
| Portable backup / restore | `lib/services/nova_backup_service.dart`, Settings backup flow | PR #142 is still separate and targets `orah-base-v1`; not yet reconciled into main |
| Ordinary attachments in backup | Backup service attachment handling | Round-trip coverage needs confirmation |
| Vault portability with passphrase | Implemented on PR #142 branch | Do not treat as production-main capability until safely ported and tested |
| Vault attachment portability | Implemented on PR #142 branch | Cross-device round-trip pending |
| Atomic restore rollback | Implemented/tested in PR #142 branch | Main integration and complete rollback evidence pending |
| PDF / Word / text / Markdown / Excel exports | Export sheet and universal export service | Individual format tests and entitlement checks needed |
| Email attachment | Feature catalogue describes PDF sharing through device share sheet | Verify email app handoff; no dedicated test confirmed |
| Additional formats | Feature catalogue explicitly labels them **Planned** | Not implemented/available as a completed feature |

## G. Monetization and entitlements

| Feature | Source evidence | Test evidence / status |
|---|---|---|
| ORAH Pro screen | `orah_pro_screen.dart` | Screen exists; purchase lifecycle must be verified |
| Entitlement service | `orah_entitlement_service.dart` and feature gate | `orah_feature_gate_test.dart` exists |
| Premium feature gating | `orah_feature_gate.dart`, `orah_premium_gate.dart` | Test coverage exists but all entry points/paywalls need audit |
| Purchase / restore purchases | Pro screen offers purchase choices and restore action | Real Play Billing sandbox and restore tests required |
| Lifetime option visibility | Must be checked against current product catalogue and Play Console products | Not verified in this source-only audit |
| Free vs Pro export entitlements | Export service and premium gates | Format-by-format entitlement matrix required |

## H. App shell, settings and platform

| Feature | Source evidence | Test evidence / status |
|---|---|---|
| Home navigation / bottom navigation | `lib/app.dart` | Widget test exists; all destinations not exhaustively checked |
| Settings / appearance | Settings screen and theme controller | Theme persistence UI test needed |
| Android features | Android features screen | Physical-device verification required |
| Registration / profile | Entry gate and registration screens | Registration journey test needed |
| Privacy pledge / About | Dedicated screens | Source present; no critical flow test |
| Localization | Generated localization setup and translation files | CI generation/analyze; all translated strings need review |
| Notifications / reminders | Reminder service | Permission, reboot and delivery tests needed |

## Existing automated test files found on main

- `test/screens/feature_preservation_test.dart`
- `test/widget_test.dart`
- `test/note_repository_concurrent_mutation_test.dart`
- `test/note_repository_stream_regression_test.dart`
- `test/note_tag_filter_test.dart`
- `test/linked_notes_model_test.dart`
- `test/note_version_history_test.dart`
- `test/data/database/orah_database_test.dart`
- `test/data/kanban/kanban_repository_test.dart`
- `test/data/kanban/kanban_migration_test.dart`
- `test/screens/kanban_screen_test.dart`
- `test/orah_feature_gate_test.dart`
- `test/orah_hardening_test.dart`
- `test/orah_platform_test.dart`
- `test/orah_universal_search_index_test.dart`
- `test/focus_session_service_test.dart`
- `test/prompt_service_test.dart`
- `test/speech_to_text_test.dart`
- `test/streak_service_test.dart`
- `test/competitive_upgrade_test.dart`
- `test/global_audit_test.dart`

## Highest-risk gaps to close next

1. Add a dedicated Undo-delete regression test.
2. Test permanent deletion and empty Trash confirmation.
3. Test folders, pin/favorite, archive/unarchive and duplicate/merge attachment preservation.
4. Test editor autosave, checklist, attachment add/remove and note reopen.
5. Audit every feature-gate entry point against the free/Pro product matrix; confirm no stale Lifetime SKU or accidental paywall.
6. Run purchase/restore flows in Play Billing test environment.
7. Complete reminder, calendar, reflection and Pomodoro notification/lifecycle device tests.
8. Reconcile PR #142 from `orah-base-v1` to current `main` carefully; do not merge it as-is.
9. Install the exact main-branch release build on a physical Android device and execute the release checklist.

## Audit conclusion

The repository contains a broad set of implemented screens, services, models and tests. The most meaningful automated coverage is around repository/database behavior, Kanban, search indexing, focus sessions, speech service and the new critical note-preservation journeys.

This audit is **not** a claim that all listed features are working in production. Items marked not verified require focused tests or physical-device acceptance before being called complete.
