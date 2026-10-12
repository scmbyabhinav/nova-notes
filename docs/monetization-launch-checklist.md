# ORAH Pro, free trial, and offer rollout

## Current paywall changes

The ORAH Pro screen now explains the value of Pro before presenting the Google Play monthly and yearly products. It highlights OCR, premium exports, advanced search, and productivity tools, keeps store-localized prices, offers Restore Purchases, and includes clear subscription renewal/cancellation language.

**Do not announce a live 7-day trial until the Google Play offer is configured and the app selects the matching offer token.** The current purchase service queries product details by product ID and may choose the first returned subscription offer. A trial must not be advertised as active until this selection path is tested with a Play license tester.

## Recommended plan positioning

- **Free:** everyday notes, checklists, folders, local access, plain-text and Markdown export.
- **ORAH Pro:** OCR, premium PDF/Word/Excel exports, advanced search, premium templates and other advanced features only when shipped and tested.
- Keep existing notes accessible if a subscription expires. Premium gates should block new premium actions, not hold a user's own content hostage.
- Starting prices to configure in Play Console: ₹149/month and ₹1,399/year. Always display the localized prices returned by Google Play; these figures are planning prices, not hard-coded UI prices.

## Configure the 7-day trial in Google Play Console

1. Open **Monetize with Play → Products → Subscriptions**.
2. Open the subscription products `orah_pro_monthly` and `orah_pro_yearly`; confirm each has an active base plan.
3. Add a **new-customer offer** to the relevant base plan. Configure a **7-day free trial** and restrict eligibility to new subscribers.
4. Give the trial offer a stable offer tag such as `orah_7day_trial`. Apply it consistently to the plans on which the trial should be available.
5. Activate the offers and save. Verify the offer is available to the app's license testers.
6. Update the Flutter billing path to identify the tagged offer, pass its Google Play `offerToken` when purchasing, and show the regular renewal price and billing period alongside the 7-day trial. Do not assume every user is eligible.
7. Test: eligible first-time account, ineligible returning subscriber, cancellation before renewal, renewal after trial, restore purchases, pending payment, offline/error handling, and subscription expiry.
8. The confirmation UI and Google Play checkout must make clear that the trial lasts 7 days, when billing starts, the renewal amount and frequency, and how to cancel. Never imply that a trial is free forever.

## Developer-issued promo codes and corporate offers

Use Google Play's own subscription offers and promo-code redemption flow for Play-distributed subscriptions. Do **not** invent a local text code that unlocks Pro only on the device: it can be copied, forged, or lost on reinstall, and would bypass verified billing.

### Small creator / launch campaigns

- Create a named, time-limited offer in Play Console (for example, `ORAH_LAUNCH` in internal campaign tracking; the actual offer is configured in Play Console).
- Decide eligibility, duration, and any discounted period before publishing. Use a distinct campaign/offer for each partner so results can be measured.
- Distribute the official Google Play redemption link/code privately to the intended recipients.
- Keep a simple ledger of campaign name, issue date, recipient/company, quantity, expiry, and redemption outcome. Never record payment credentials or purchase tokens in a spreadsheet.
- Confirm current Play Console limits and supported promo-code mechanics before promising a number of codes or a particular discount. Offer availability differs by subscription setup and region.

### Corporate / bulk purchases

Start with a **managed corporate offer** rather than building an insecure in-app coupon engine:

1. Offer a volume-based discount policy (for example, 10–24 seats, 25–99 seats, and 100+ seats) as a commercial proposal, not as a hard-coded price promise.
2. For Google Play distribution, verify whether managed Google Play subscriptions and the customer's organization setup support the exact purchase and entitlement model required.
3. If a company needs centralized seat assignment, invoicing, employee onboarding/offboarding, or cross-device entitlements, build a small authenticated backend and admin console. The backend must verify Play purchases with the Google Play Developer API, track organization/seat assignments, prevent code reuse, and support revocation and audit history.
4. Never put a service-account key or Google Play Developer API credential in the app or GitHub repository. Store server credentials in the backend secret manager.
5. For the first launch, handle corporate requests manually and issue only the store-supported offer mechanism. Add automated seat management after consumer billing and retention are proven.

## Release acceptance checklist

- [ ] Google Play subscription products are active and return localized prices.
- [ ] 7-day trial offer is active, tagged, selected by the purchase flow, and tested with eligible and ineligible test accounts.
- [ ] Paywall does not claim trial availability when Google Play does not return the trial offer.
- [ ] PDF, Word, and Excel premium export gates match the product decision; plain text and Markdown remain free.
- [ ] OCR is actually implemented, reliable, and gated as Pro before being promoted.
- [ ] Restore, cancellation, expiry, failed verification, and offline paths are tested.
- [ ] No arbitrary local coupon unlock exists; promo redemption is backed by Google Play.
- [ ] Privacy policy and Play Console Data safety declarations match actual analytics, OCR, and billing behavior.
