# Orah 

Orah is a fast, private, offline-first note-taking app.

**Think it. Write it. Keep it.**

## Product direction

Orah combines the speed of Google Keep, the power of Samsung Notes, the polish of Apple Notes, and the organization of OneNote without unnecessary complexity. V1 is local-first and does not require an account or backend.

## Build progress

- ATTACK 1 — foundation
- ATTACK 2 — premium home UI
- ATTACK 3 — real notes + local persistence
- ATTACK 4 — folders, favorites, tags, archive
- ATTACK 5 — search + filters
- ATTACK 6 — security & privacy foundation
- ATTACK 7 — files & backup foundation
- ATTACK 8 — Android integration architecture
- ATTACK 9 — polish & performance foundation
- ATTACK 10 — Play Store release preparation
- ATTACK 11+ — competitive upgrade, export, rich editor, attachments, checklist engine, backup and reliability

## Run

```bash
flutter pub get
flutter run
```

## Global product audit

See `GLOBAL_PRODUCT_AUDIT.md` for localization, accessibility, privacy, Unicode, timezone, offline and international-release requirements.


CI build trigger: Orah Android validation and APK packaging.


## Production release checklist

- Confirm the final Play Store package/application ID before production signing.
- Create and securely store the production upload/release keystore; never commit signing material.
- Configure Play Console Data safety, content rating, target audience, privacy policy, and app access declarations.
- QA clean install, upgrade, backup/restore, reminders, checklist reminders, OCR, export/share, app lock, Trash, themes, and offline behavior on physical Android devices.
