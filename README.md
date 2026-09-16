# NOVA Notes

NOVA Notes is a fast, private, offline-first note-taking app.

**Think it. Write it. Keep it.**

## Product direction

NOVA combines the speed of Google Keep, the power of Samsung Notes, the polish of Apple Notes, and the organization of OneNote without unnecessary complexity. V1 is local-first and does not require an account or backend.

## ATTACK 2 — Premium Home Screen

ATTACK 2 upgrades the home experience with a polished NOVA header, search, pinned notes, recent note cards, grid/list switching, demo content, and a refined empty/loading-ready structure.

## ATTACK 1 — Foundation

This milestone establishes:

- Flutter project structure
- Material 3 theme
- NOVA visual identity
- App shell and navigation
- Note model
- Folder model
- Settings model
- Repository contract for future local persistence

## Run

```bash
flutter pub get
flutter run
```

## Build later

The Android release pipeline will be added after the core app is functional.


## Build progress
- ATTACK 1 — foundation
- ATTACK 2 — premium home UI
- ATTACK 3 — real notes + local persistence
- ATTACK 4 — folders, favorites, tags, archive
- ATTACK 5 — search + filters
- ATTACK 7 — files & backup foundation

- ATTACK 8 — Android integration architecture
- ATTACK 6 — security & privacy foundation
- ATTACK 9 — polish & performance foundation
- ATTACK 10 — Play Store release preparation

## Global product audit
See `GLOBAL_PRODUCT_AUDIT.md` for localization, accessibility, privacy,
Unicode, timezone, offline and international-release requirements.
