# NOVA Notes — ATTACK 6: Security & Privacy

## Added
- Secure PIN storage using `flutter_secure_storage`.
- Salted SHA-256 PIN verification.
- 4–8 digit PIN support.
- App-lock settings.
- Biometric capability detection and OS biometric authentication.
- Dedicated NOVA lock screen.
- Security & Privacy settings page.
- Note model already supports `isLocked` state.

## Important security boundary
The PIN itself is not stored in SharedPreferences or plaintext.

The current notes database remains local SharedPreferences storage. Therefore
this release should NOT claim that note bodies are encrypted at rest.

The next security hardening step is an encrypted note vault for locked-note
content before publishing a strong "encrypted notes" claim.

## Native setup later
`local_auth` needs the generated Android/iOS platform configuration and device
biometric permissions when the project is built on the laptop.
