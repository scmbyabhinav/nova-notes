# NOVA Notes — Global Product Audit

## Product strengths to preserve
- Fast capture
- Offline-first/local-first
- No mandatory account
- Clean organization
- Search
- Device-level protection
- Portable data direction

## Global requirements now addressed in the codebase
- Locale-ready Flutter app architecture
- Supported locale list for major global languages
- RTL-capable Flutter localization setup
- Unicode-safe String-based note model
- Locale-aware date/time formatter
- System 12/24-hour formatting through `intl`
- Accessibility semantics foundation
- Reduced-motion awareness
- System theme compatibility
- No hard dependency on a specific country or timezone

## High-priority global gaps for device validation
1. Complete translation coverage for every user-facing string.
2. Verify Arabic RTL layouts and long translated strings.
3. Test large accessibility font scales.
4. Test TalkBack/screen-reader navigation.
5. Verify Android permission dialogs in each supported API level.
6. Verify date/time rendering across timezones and DST regions.
7. Test Unicode/emoji/CJK text and mixed-direction text.
8. Test very long note titles and filenames.
9. Test low-storage and interrupted-write scenarios.
10. Test backup import from older NOVA versions.
11. Add proper encrypted storage before making encryption claims.
12. Add privacy policy and Play Data Safety declarations matching the final build.
13. Add crash reporting only if needed, with data minimization.
14. Verify offline behavior with airplane mode.
15. Verify performance with thousands of notes.

## Product opportunities for a global V2
- Full professional localization
- PDF annotation
- OCR
- handwriting/drawing
- audio notes/transcription
- encrypted note vault
- cross-device encrypted sync
- robust attachment storage
- richer widgets
- desktop/web companion

## Release principle
Global-ready does not mean feature-bloated. NOVA should remain fast and simple,
with advanced capabilities layered behind optional flows.
