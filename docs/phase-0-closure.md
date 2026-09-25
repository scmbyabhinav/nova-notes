# Phase 0 — Quick Capture test fix: CLOSED 2026-09-25

Gate: two consecutive fully-green push-triggered Orah runs.

- Run #42 ✅ — commit `db83c64a` — analyze, full suite (both Quick Capture
  tests executed and passed), debug APK, release APK/AAB, artifacts.
- Run #43 ✅ — commit `752a760e` — run ID `36116636758`, push-triggered,
  conclusion: success.

## Fixes applied during Phase 0

- Run #36 — reset mocked SharedPreferences per widget test.
- Run #35/#36 lineage — made widget tests independent of platform
  SharedPreferences and removed `pumpAndSettle()` deadlock risk.
- Run #37 — replaced the Quick Capture tap path with a deterministic
  `pump() → 300ms pump → pump()` sequence; the immediate note test passed.
- Runs #38–40 — instrumented the long-press path, targeted the actual
  FloatingActionButton, and made the long-press gesture deterministic.
- Run #41 — gesture change introduced a duplicate `dispose()` in
  `lib/app.dart`, causing analysis to fail before tests ran.
- `db83c64a` — fixed the misplaced duplicate `dispose()` and restored the
  intended timer cleanup in `_NovaShellState`.
- Runs #42 and #43 — analysis and the complete Flutter test suite passed;
  both Quick Capture tests executed successfully.
- Run #44 — docs-only baseline run also passed, giving four consecutive
  successful test suites after the Quick Capture repair.

## Phase 0 exit criteria

**MET.** Two consecutive fully-green, push-triggered Orah runs (#42 and #43)
validated the repaired Quick Capture behavior.

## Phase 1 — Debug APK decoupling: CLOSED 2026-09-25

**Verification run:** #46 (SHA `5555b2a5`).

- `test` and `debug-apk` started at 10:34:48 / 10:34:49 UTC — parallel,
  with no `needs:` dependency.
- Both jobs succeeded.
- Release APK (44.0 MB) and AAB (76.0 MB) were produced behind the test job.
- Debug artifact `orah-debug-apk-5555b2a5...` was uploaded at 106.9 MB
  with 14-day retention.
- The legacy `nova-android-ci.yml` workflow was removed before #46.

### Run numbering / implementation note

- Run #45 (SHA `ff427344`) was the intermediate state: the job split had
  landed, but the legacy workflow still existed. It is not the final Phase 1
  verification run.
- Run #46 (SHA `5555b2a5`) is the first clean graph with only the Orah
  workflow.
- The Phase 1 change required two sequential commits because the GitHub
  Contents API applied the workflow split and legacy-workflow removal
  separately.

### Timing

- #44 pre-split: **26m22s** sequential wall-clock.
- #46 post-split: **15m35s** wall-clock.
- The critical path lost the serial debug build/upload because those steps now
  overlap the test/release job. Duplicated setup overlapped with that work.
- Trade accepted: higher total CI runner-minutes in exchange for approximately
  41% lower developer wall-clock time and debug-APK availability while tests
  are red.

### Open item

Branch protection may still reference the old `build` job name after the
rename to `test`. This is not verifiable through the current API token;
verify Settings → Branches before merging PR #74.

## Phase 2 planning decisions

### Embedding model packaging

Decision pending final Phase 2 implementation review: prefer an offline-capable
bundled quantized embedding model rather than a first-launch network download.
The one-time model-size increase should be explicitly exempted from the
>10% build-size regression baseline, while subsequent regressions remain
enforced. Play-delivered on-demand packaging can be evaluated as an
optimization, with keyword-search fallback for installs that do not receive
the model.

### Device-support homework

SDK values still need to be read from the Android Gradle configuration before
the Phase 2 support/fallback matrix is finalized.


## Batch A — Regression fixes + UX polish — 2026-09-25

- Task 1 — reactive note-library updates: commit `6a40f62b`; follow-up cleanup `c7977803`.
  Home now listens to the same `LocalNoteRepository` stream used by the editor,
  and the widget suite includes a create → pop → immediate library assertion.
- Task 2 — voice capture prominence: commit `54c8fb05`; follow-up wiring fix
  `c94ac565`. Added the editor M3 mic FAB, one-time voice hint, mocked speech
  widget coverage, and automatic title generation from the first transcript line.
- Task 3 — quick-capture discoverability: commit `471e2238`. The home FAB is
  now a standard circular mic FAB with a persistent first-two-visits hint while
  preserving the existing long-press capture menu behavior.
- Task 4 — Android feature actions: commit `6db056e2`. Widget and shortcut rows
  now explain/use their native actions, Share to ORAH launches a real Android
  share intent into ORAH, and Reminders opens note creation with reminder setup.

Verification: CI must remain the source of truth for the full Flutter analyze/test
suite and parallel Android jobs. Local Flutter/Dart execution was not available
in the execution environment used for this batch.
