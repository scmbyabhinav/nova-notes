# ORAH Actions — Phase 2 (local-only)

## Scope
This increment introduces the on-device action record and scheduling service. It deliberately adds no API, OAuth, account connection, hosted backend, or integration middleware.

## Current implementation
- OrahAction persists ID, title, scheduled time, device time-zone label, recurrence, status, retry count, and last scheduling error in SharedPreferences.
- OrahActionsService schedules Android local notifications and supports completion, cancellation, daily/weekly/monthly recurrence, and bounded manual retry (up to three attempts).
- Monthly recurrence clamps to the last valid day (for example, a 31st-month schedule falls back to the 30th/28th/29th where needed).
- Data remains on this device; it is not synchronized to other devices.
- Notifications use Android's inexact-while-idle scheduling mode. Delivery can be delayed by Android battery/background policies; this is not a guaranteed exact alarm.

## Important validation and remaining work
- This is service-layer groundwork, not a finished user-facing Actions screen.
- Verify the local timezone mapping on physical Android devices, including DST transitions and timezone changes. The service records the device's current timezone label and schedules using the timezone library's local location; it does not currently install a platform-specific IANA timezone identifier.
- Add unit tests for serialization, recurrence boundaries, cancellation, retry limits, and status transitions.
- Add a localized UI to create/list/complete/cancel actions, and wire action taps to their destination.
- Run flutter pub get, flutter analyze, the full Flutter test suite, and a debug APK build; manually test notification permission, app restart, device reboot, timezone changes, and Android battery restrictions.
- Do not merge until CI and device tests pass.

## Cost guardrail
No new package, cloud service, API key, billing account, OAuth consent screen, or paid integration is introduced by this phase.
