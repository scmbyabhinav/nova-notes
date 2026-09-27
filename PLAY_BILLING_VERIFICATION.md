# ORAH Billing Verification Architecture

## Current client

ORAH uses Google Play Billing through Flutter's `in_app_purchase` package.

Product IDs are fixed in source:

- `orah_pro_monthly`
- `orah_pro_yearly`

The app listens to the purchase stream, completes pending purchases, restores purchases, and persists the current entitlement locally.

## Important production boundary

A client-only purchase cache is not a trustworthy source of subscription expiry. Subscription renewals, cancellations, refunds, grace periods, account changes, and reinstalls are ultimately controlled by Google Play.

The current app therefore treats its local entitlement logic as a **client fallback**, not as the final billing authority.

## Production verification target

The production architecture should become:

1. App receives a Google Play purchase.
2. App sends the purchase token plus product ID to an ORAH billing backend over HTTPS.
3. Backend authenticates the request and calls the Google Play Developer API.
4. Backend verifies the product, package name, purchase state, acknowledgement state, expiry, and cancellation/refund state.
5. Backend returns a short-lived entitlement result to the app.
6. App caches that result for offline use, with an explicit expiry/grace policy.
7. Google Play Real-time Developer Notifications update the backend when a subscription renews, enters grace/hold, is cancelled, or expires.

## Security rules

- Never put Google Play service-account JSON, private keys, or access tokens in the mobile app.
- Never commit billing credentials to Git.
- Never trust a product ID supplied by the client without checking the purchase token against Google Play.
- Never treat a locally fabricated expiry date as proof of an active subscription.

## What remains for Play production

The repository is prepared for this backend boundary, but the actual Google Play Developer API credentials and Play Console configuration belong outside the mobile repository.

A future backend can expose a minimal endpoint such as:

`POST /v1/billing/google-play/verify`

with product ID and purchase token, returning only the verified entitlement state needed by ORAH.

## Release implication

Monthly/yearly subscriptions must be driven by Google Play's verified expiry/state rather than a fixed 31/366-day calculation.

Until backend verification exists, the app must not claim that its local subscription date is authoritative.
