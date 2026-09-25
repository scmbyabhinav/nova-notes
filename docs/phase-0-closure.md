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

## Phase 0 exit criteria

**MET.** Two consecutive fully-green, push-triggered Orah runs (#42 and #43)
validated the repaired Quick Capture behavior.

## Follow-up: legacy workflow

The legacy `.github/workflows/nova-android-ci.yml` remains separately tracked.
It is not part of the Phase 0 gate and currently produces failures on this
branch. Phase 1 will address CI workflow separation/quarantine so persistent
legacy red checks do not obscure the authoritative Orah workflow.

## Phase 1 baseline

The authoritative `.github/workflows/orah-android-build.yml` currently uses
one `build` job. Debug APK creation/upload is already present, but it occurs
after Analyze/Test in that same job. Phase 1 will split the debug APK into an
independent job with no `needs:` dependency while keeping release builds
behind the test job.
