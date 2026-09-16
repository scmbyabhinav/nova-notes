# NOVA Notes — Attack 10 Release Checklist

## Current release target
- Product: NOVA Notes
- Suggested Android application ID: `com.abhinav.novanotes`
- Initial version: `1.0.0+1`
- Release channel: Google Play production
- Architecture: local-first, offline-first

## Before building the AAB
1. Install/update Flutter SDK and Android SDK on the laptop.
2. From the project root run:
   - `flutter create .`
   - `flutter pub get`
   - `flutter analyze`
   - `flutter test`
3. Resolve every analyzer error before release.
4. Test on a physical Android device.
5. Test:
   - create/edit/delete note
   - restart persistence
   - folders/tags/favorites/pin/archive
   - search/filtering
   - PIN/app lock
   - biometric unlock
   - backup/import
   - dark/AMOLED theme
   - keyboard and back navigation
   - accessibility text scaling
6. Configure a unique release signing key. Never commit the keystore or passwords to GitHub.
7. Build:
   `flutter build appbundle --release`
8. Upload the generated `.aab` to Google Play Console.
9. Complete Play Console app content, privacy/data safety, store listing, screenshots,
   content rating and target audience declarations.
10. Use an internal/closed test track before production.

## Important
The AAB cannot be honestly generated inside this environment because the Android
platform project, local Flutter SDK, Android SDK, Gradle setup and release signing
credentials belong on the development machine.

## Security
Do not claim encrypted note storage or end-to-end encryption in the store listing
until locked-note content has been moved from SharedPreferences into encrypted
storage.

## Suggested store positioning
NOVA Notes — fast, private, offline-first notes.

Tagline:
Think it. Write it. Keep it.

Avoid claims that cannot be verified on the shipped build.
