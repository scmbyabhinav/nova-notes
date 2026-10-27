# ORAH-F04 Gate 0 — CI Baseline

**Persistence test commit:** `6448b1620703d4251bdaae9cb807835726f65e33`

The persistence implementation and schema-upgrade test are present on `feature/orah-f04-study-kanban`. This commit exists only to trigger push-based GitHub Actions against the branch state containing the migration and persistence tests.

Gate 0 is complete only when the Actions run for this commit finishes successfully for the required test and debug-APK jobs. No Kanban UI implementation should begin before that result is verified.
