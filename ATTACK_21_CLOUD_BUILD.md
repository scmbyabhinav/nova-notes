# Attack 21 — Cloud Build

NOVA now has a GitHub Actions CI pipeline.

It:
- installs Flutter on a cloud runner;
- generates the Android platform project;
- resolves dependencies;
- runs `flutter analyze`;
- runs `flutter test`;
- builds a debug APK;
- uploads the APK as a GitHub Actions artifact.

Release signing and Play Store AAB publishing are deliberately not included yet. Those require protected signing secrets and should be added only after CI is green.

The Android platform folders remain generated in CI rather than committed to the source repository.
