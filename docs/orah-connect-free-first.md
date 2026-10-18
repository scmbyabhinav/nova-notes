# ORAH Share & Export — strict ₹0 integration policy

## Decision

ORAH will not implement direct Google Drive, Gmail, OneDrive, or Outlook API connections in this increment. The project owner requires no billing account, no paid API, and no risk of unexpected integration-service charges.

## Implementation

- Reuse the existing `share_plus` package for native Android sharing.
- Reuse the existing `file_picker` package for user-initiated local file selection where needed.
- Keep note creation, editing, searching, and storage local-first and available offline.
- Users can choose an installed cloud-storage or email app from Android's share sheet when that app supports the shared content.
- Use the existing note editor's Share and Export actions to share actual note content or exported files. This screen is informational; it does not connect accounts or claim background sync.
- Do not request Google or Microsoft OAuth permissions, call Drive/Gmail/Graph APIs, store cloud tokens, or add cloud middleware.

## Cost and privacy guardrails

- Do not enable Google Drive API or create OAuth credentials for this implementation.
- Do not configure a billing account for integrations.
- Do not add paid SDKs, hosted integration services, background sync, or API usage.
- Native sharing hands content to an app the user chooses. ORAH cannot guarantee that a third-party app is installed, free, or completes an upload; any action in that app is controlled by the user and provider.
- Do not claim that sharing is the same as cloud backup or automatic sync.

## Validation checklist

1. Confirm `google_sign_in` is removed from `pubspec.yaml` and there are no references to the Google connection service.
2. Run `flutter pub get`, `flutter analyze`, and the complete Flutter test suite.
3. Build the debug APK using the existing GitHub Actions workflow.
4. On an Android device, open a note and test Share, Send as email attachment, and each currently supported export format.
5. Test importing a local file with the existing file picker where that flow is exposed.
6. Confirm all 14 ARB locale files remain structurally valid and localization generation passes.
7. Keep this PR in draft and unmerged until CI is green and the native sharing flow has been manually verified.
