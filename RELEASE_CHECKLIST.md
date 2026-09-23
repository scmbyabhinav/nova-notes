# ORAH — Release Checklist

## Current release target

- Product: ORAH
- Version: `1.0.0+1`
- Release channel: Google Play production
- Architecture: local-first, offline-first
- Android host: generated during CI from the Flutter project, then patched by `tool/prepare_android_host.py`

## Automated source checks

Before release, run:

```bash
python3 tool/release_audit.py
flutter pub get
flutter analyze --no-fatal-warnings --no-fatal-infos
flutter test
```

The GitHub workflow generates the Android host and builds a debug APK, release APK and release AAB. The normal CI AAB is not Play-uploadable; production signing requires production_release=true and the four protected signing secrets.

## Android / Play release

- CI uses Java 17 and the generated Gradle wrapper.
- The PR CI trigger must produce a real workflow run before the build is considered verified.
- The Gradle project must pass its task graph validation before APK/AAB packaging.
- The ORAH application ID must be verified immediately before release APK/AAB packaging.
- Android identity is verified as `com.orah.orah_notes`.
- APK/AAB output directories and archive integrity are checked in CI.
- Release artifact checksums are retained with the build artifacts.


1. Verify the generated Android application ID in the CI build output.
2. Configure a unique release signing key. Never commit the keystore or
   passwords to GitHub.
3. Create the three ORAH Pro products using the exact IDs in
   `PLAY_BILLING_SETUP.md`.
4. Publish `PRIVACY_POLICY.md` at a real HTTPS URL controlled by the publisher, then complete Play Console app content, privacy/data safety, store listing,
   content rating and target-audience declarations.
5. Provide a real, publicly reachable privacy-policy URL.
6. Test the release AAB on an internal/closed Play track before production.
7. Verify purchase, restore, subscription expiry/cancellation and Lifetime
   entitlement behavior with Play test accounts.
8. Verify share intake, home-screen shortcuts, widget actions, notifications,
   attachments, OCR, export, biometric/app lock and backup/restore on physical
   Android devices.

## Product split

### Free

- Core local note creation/editing
- Checklists
- Folders, tags, pin/favorite/archive
- Basic search
- Text and Markdown export
- Basic attachments
- Local-first/offline use

### ORAH Pro

- OCR
- Smart capture/detection
- Advanced search operators
- PDF/Word/Excel export
- Premium templates
- Future advanced attachment tools
- Future encrypted backup/sync capabilities

The exact feature gate remains controlled by the source code; do not advertise
future features as available until they ship.

## Security

Do not claim end-to-end encryption or encrypted cloud sync. ORAH does not yet
have a server-side sync/verification backend.

## Final release gate

Do not mark the release ready solely because a workflow file exists. The
Android build, tests and AAB must actually complete successfully, and Play
Console configuration must be verified separately.

## Automated release integrity
- [ ] VERSION and pubspec.yaml version match.
- [ ] Android application ID is com.orah.orah_notes.
- [ ] Production signing is enabled only through GitHub Actions secrets.
- [ ] A production dispatch uses production_release=true.
- [ ] Release AAB is non-empty and passes tool/release_audit.py.
- [ ] APK and AAB archives pass CI integrity checks.
- [ ] CI artifact SHA-256 checksums are retained.
- [ ] Production AAB is signed only through the protected upload-key path.
- [ ] Billing verification architecture is present; client-side subscription dates are not authoritative.
- [ ] Play Console product IDs exactly match the source product IDs.