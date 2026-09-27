# ORAH Billing Verification Architecture

ORAH uses Google Play Billing through Flutter's `in_app_purchase` package. The only Pro products are `orah_pro_monthly` and `orah_pro_yearly`.

## Client verification boundary

The app sends `PurchaseDetails.verificationData.serverVerificationData` (the Google Play purchase token) and the product ID to a server endpoint before granting Pro.

Configure the endpoint at build time:

```text
--dart-define=ORAH_VERIFY_PURCHASE_URL=https://<your-backend>/v1/billing/google-play/verify
```

Request:

```json
{"purchaseToken":"<Google Play purchase token>","productId":"orah_pro_monthly"}
```

Response:

```json
{"valid":true,"productId":"orah_pro_monthly","expiresAt":"2026-10-27T12:00:00Z"}
```

The client grants Pro only when the server returns `valid: true`, the same product ID, and a future expiry. A missing endpoint, HTTP error, invalid response, or failed validation never grants Pro.

## Backend responsibility

The endpoint must authenticate the request and validate the purchase token with the Google Play Developer API. For subscriptions, it should return the authoritative expiry and cancellation/refund state. A Firebase Callable Cloud Function named `verifyPurchase` is a suitable deployment target.

The Google Play service-account credentials and API access remain server-side and are never shipped in the mobile app.

## Release rule

Only server-verified entitlements are cached locally. The mobile client no longer fabricates a 31/366-day expiry from the transaction date.
