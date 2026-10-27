# Attack 16 — Attachment Upgrade

## Included
- Full-screen image preview with pinch-to-zoom.
- Attachment action menu: preview, share, rename, details, remove.
- Native system share sheet for individual attachments.
- Safe attachment renaming while preserving extensions.
- File size and modified-time details.
- Attachment cleanup when a note is permanently deleted.
- Existing checklist state is preserved while saving notes.

## Scope
Attachments remain local-first files inside NOVA's app documents directory. They are not encrypted yet. Cross-device/cloud attachment sync remains a future feature.

## Validation
Flutter analyzer, tests, and Android device validation remain pending until the Flutter SDK and Android toolchain are installed locally.
