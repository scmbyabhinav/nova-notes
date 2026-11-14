# ORAH Release Acceptance Checklist

This checklist is mandatory for every production APK/AAB release.

## 1. Source and change control

- [ ] Release commit is on `main`; record the full SHA.
- [ ] Release changes arrived through a reviewed pull request.
- [ ] No unapproved feature removal, hiding, paywall, entitlement, or navigation change.
- [ ] Feature registry updated for every changed feature.
- [ ] Database schema/migration compatibility reviewed, including upgrade from the previous production version.

## 2. Automated quality gates

- [ ] `flutter analyze --no-fatal-warnings --no-fatal-infos` passes.
- [ ] Full `flutter test` suite passes.
- [ ] Dedicated feature-preservation suite passes:
      `flutter test test/screens/feature_preservation_test.dart`.
- [ ] Android API target verification passes (API 36+).
- [ ] Debug APK build succeeds.
- [ ] Release APK and AAB builds succeed.
- [ ] Production signing is verified when producing a store upload.

## 3. Critical feature regression checks

- [ ] Create note, edit note, auto-save, close and reopen.
- [ ] Merge two notes; confirm merged content, tags, attachments, checklist items and links are preserved; source removal occurs only after confirmation.
- [ ] Delete to Trash; Undo restores the note.
- [ ] Restore from Trash.
- [ ] Permanently delete one note and empty Trash only after confirmation.
- [ ] Search, sort, filters, folders and tags.
- [ ] Checklist, reminders, attachments and image preview.
- [ ] Pin, favorite, archive and unarchive.
- [ ] Vault unlock, lock, PIN recovery and private-note safety.
- [ ] Export and share formats available under the correct entitlement.
- [ ] Kanban, goals, focus sessions and linked notes.

## 4. Backup and recovery

- [ ] Create a backup with ordinary notes and attachments.
- [ ] Restore into a clean app installation and verify content/files.
- [ ] Portable Vault restore with passphrase on a different device/profile.
- [ ] Wrong passphrase and tampered archive are rejected without mutation.
- [ ] Simulated restore failure leaves the original database, preferences and files intact.

## 5. Device acceptance

- [ ] Install the exact release APK built from the recorded SHA.
- [ ] Upgrade-install over the previous production build and verify data migration.
- [ ] Cold launch, background/resume and restart.
- [ ] Test critical flows on a physical Android device.
- [ ] Confirm no crashes, missing actions, broken navigation or blank screens.
- [ ] Archive APK/AAB, CI run URL, SHA, test evidence and known limitations.

## 6. Branch protection (repository administrator action)

Configure GitHub Settings → Branches → Branch protection rule for `main`:

- Require a pull request before merging.
- Require the `Orah Android Build / test` check.
- Require the `Orah Android Build / debug-apk` check.
- Require at least one approval if a second reviewer is available; otherwise use the owner's explicit review.
- Require branches to be up to date before merging.
- Block force pushes and branch deletion.
- Do not allow bypassing required checks for routine feature work.

The workflow can enforce tests on PRs, but repository branch-protection settings must be enabled in GitHub's repository settings by an administrator.
