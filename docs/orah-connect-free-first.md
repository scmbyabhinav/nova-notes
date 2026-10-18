# ORAH Connect — free-first implementation notes

## Current implementation status

- Google Drive: native Google account sign-in foundation is added in `lib/services/orah_google_connect_service.dart`. The Connect screen can connect/disconnect a Google account and restore an existing session.
- Drive access uses only `drive.file`, not broad access to every file in the user's Drive. The service can list files that Google makes available under that scope.
- Gmail, OneDrive, and Outlook remain not connected. They must not be presented as working until their OAuth and API paths are implemented and tested.
- Google access tokens are requested from the sign-in SDK when needed and are not copied into preferences or source code.
- No paid middleware or AI service is introduced.

## Google Cloud setup required before testing on a device

Google OAuth requires a one-time developer-console setup; the API itself has a free quota. Do not commit OAuth client secrets, access tokens, refresh tokens, or `google-services.json` unless the project intentionally uses and safely manages that Firebase configuration.

1. Open Google Cloud Console and create/select a project for ORAH.
2. Configure the OAuth consent screen. While testing, set the app to **Testing** and add your own Google account as a test user.
3. Enable **Google Drive API**.
4. Register an **Android OAuth client** using the generated Android application ID `com.orah.orah_notes`.
5. Add the SHA-1 certificate fingerprint for the debug build you are testing. Add the production/Play signing fingerprint separately before release.
6. Build and run the app. In Settings → Connected apps, tap **Connect** on Google Drive and complete Google's account/consent flow.

The repository CI generates the Android host project during the workflow, so Android files may not exist in the checked-in source tree. The current workflow uses `flutter create --platforms=android --org com.orah --project-name orah_notes`.

## Scope and privacy decisions

- Current Google scope: `email` plus `https://www.googleapis.com/auth/drive.file`.
- `drive.file` is deliberately narrower than full Drive access. It is appropriate for files the user opens/creates with ORAH or explicitly selects for ORAH; it does **not** mean ORAH can browse every file in the account.
- Gmail permissions are not requested by this first increment. Gmail read scopes can trigger additional Google verification requirements, so add them only when the Gmail feature and its review requirements are ready.
- Never put OAuth client secrets in the Flutter app. Native public-client OAuth IDs are not secrets, but must match the registered package/signing fingerprint.
- If the user disconnects, ORAH signs out of this app; it does not delete cloud files.

## Next implementation increments

1. Validate this Google sign-in increment with CI and a real test device.
2. Add a user-visible Drive file list and open/share flow, with loading/error/empty states.
3. Implement Microsoft OAuth for OneDrive using a registered Microsoft Entra app and the minimum Graph permissions.
4. Add Gmail, then Outlook, only after scopes, verification, and privacy disclosures are reviewed.
5. Keep the 14-locale ARB parity test green for every new visible string.
