# Attack 11 — NOVA Competitive Upgrade

## Goal

Strengthen NOVA against modern note apps without turning V1 into a feature-heavy clone.

Current competitive reference points include Samsung Notes capabilities such as S Pen handwriting, PDF annotation, audio/notes synchronization, folders/subfolders, searchable tags, and Galaxy AI note assistance. NOVA's strategy is device-neutral, local-first capture, fast retrieval, and privacy-forward architecture.

## Implemented in this attack

### 1. Quick Capture
- Replaced the generic New Note FAB with **Quick capture**.
- Added one-tap entry points for:
  - Quick note
  - Quick checklist
- Capture flow explicitly prioritizes speed: capture first, organize later.
- Android integration architecture from Attack 8 remains the path for launcher shortcuts and Share-to-NOVA.

### 2. Search upgrade
- Search now treats multi-word queries as separate terms.
- All query terms must be present for a result.
- Results are ranked by relevance:
  - exact title match
  - title match
  - exact tag match
  - partial tag match
  - content match
  - recent update as a tie-breaker
- Added folder filtering to Search.
- Existing favorites, pinned, archived, and note-type filters remain.

### 3. Note-type foundation
- New notes can be created directly as text or checklist notes.
- Existing notes retain their stored note type.
- The editor can switch between text and checklist mode.
- Persistence stores the selected type.

### 4. Code quality
- Fixed explicit control flow in note action switches so actions cannot accidentally fall through.
- Preserved local-first storage and existing backup compatibility.

## Deliberately not claimed as complete

These are next-stage features because they require real device/platform work or stronger storage architecture:

- S Pen / handwriting canvas
- PDF annotation
- OCR
- audio recording/transcription
- encrypted note database / true encrypted vault
- cloud sync
- AI summarization / translation
- Android launcher shortcut and Share-to-NOVA native implementation

NOVA must not claim encrypted note content until the note database itself is encrypted at rest.

## Product direction

NOVA is not intended to reproduce every Samsung Notes feature. The differentiator is:

**Fast capture + excellent local search + device-neutral Android experience + privacy-first architecture.**

## Validation required on the user's Windows machine

Run:

```powershell
flutter pub get
flutter analyze
flutter test
```

Then test Quick Capture and Smart Search on a real Android device.
