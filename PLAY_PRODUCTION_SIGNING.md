# ORAH Production Android Signing

The repository never stores the Play upload keystore or passwords.

## Required GitHub Actions secrets
- `ORAH_UPLOAD_KEYSTORE_B64` — base64-encoded JKS upload keystore.
- `ORAH_KEYSTORE_PASSWORD` — keystore password.
- `ORAH_KEY_ALIAS` — upload-key alias.
- `ORAH_KEY_PASSWORD` — upload-key password.

Run the workflow manually with `production_release=true`. The keystore is decoded only on the ephemeral runner and is not committed.

## One-time setup
Create an Android upload keystore using Android Studio's Generate Signed Bundle/APK flow or `keytool`. Back it up securely.

Encode it for the GitHub secret:
`base64 -w 0 orah-upload.jks`

Add the four values as repository Actions secrets. Do not put them in YAML, source code, issues, or pull requests.

## Google Play App Signing
Google Play App Signing uses a protected app-signing key and a separate upload key. This workflow handles the upload-key signing side. Initial Play Console enrollment and certificate registration still require the publisher account.

## Important
Until the four secrets exist, normal CI remains usable, but a production-release dispatch intentionally cannot create a signed Play-uploadable AAB.