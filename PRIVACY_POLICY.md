# ORAH Privacy Policy — Draft

**Last updated:** 23 September 2026

This document is a release draft for ORAH. Before publishing the app on
Google Play, the owner should publish this policy at a stable, publicly
reachable HTTPS URL and keep it consistent with the shipped build.

## What ORAH is designed to do

ORAH is a local-first, offline-first note-taking application. The core notes,
folders, tags, checklists and attachments are intended to remain on the user's
device unless the user explicitly exports, shares or backs them up.

## Information stored on the device

Depending on the features the user uses, ORAH may store:

- Notes, checklists, folders, tags and note metadata.
- Local attachment files selected or captured by the user.
- App preferences and settings.
- Local reminder/notification information.
- Local purchase entitlement/cache information used to provide ORAH Pro access.

The user controls the notes and files stored by the app on their device.

## Purchases

ORAH Pro purchases are processed through Google Play's in-app billing system.
ORAH does not directly receive the user's payment-card details.

The app uses Google Play product identifiers for Monthly, Yearly and Lifetime
ORAH Pro purchases and restores purchases through the billing framework.

## OCR

ORAH can use Google ML Kit text recognition for OCR features. OCR processing is
performed by the ML Kit integration used by the app; the app does not
intentionally upload note images to an ORAH cloud service for OCR.

Users should review Google's applicable service/privacy documentation for the
ML Kit component included in the shipped application.

## Sharing and imports

Android share-intent support allows users to send content from other
applications into ORAH. The app processes content the user chooses to share.

## Notifications

If reminders are enabled, ORAH may schedule local notifications on the
device. Notification permission and behavior depend on the Android version
and the user's device settings.

## Home-screen features

ORAH may provide Android shortcuts and a home-screen widget for quick note,
checklist and search actions. These features are handled locally by the app.

## Data sharing

ORAH does not currently provide an ORAH-operated cloud sync service. The
project should not claim that data is synchronized to ORAH servers.

When the user deliberately uses Android sharing or an export feature, the
selected content is passed to the destination chosen by the user.

## Security

ORAH is designed as a local-first application and supports app-lock/biometric
features where available. This document does not claim end-to-end encryption
or encrypted cloud storage.

## Children's privacy

ORAH is not specifically directed at children. The final Google Play target
audience and related declarations must be completed in Play Console.

## Changes

This policy should be updated if the app adds analytics, advertising, cloud
sync, server-side account features, or other data-processing behavior.

## Contact

Before publication, add a real privacy/contact address controlled by the app
publisher. Do not publish a placeholder contact address.
