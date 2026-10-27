# NOVA Notes — ATTACK 8: Android Integration

## Added
- Android platform bridge service using a MethodChannel.
- Quick Note / Checklist action component.
- Android Features screen documenting native integrations.
- Architecture for:
  - home-screen widget
  - launcher Quick Note shortcut
  - Share to NOVA
  - future reminder notifications

## Why the native Android folder is not included yet
The current project was intentionally built without generated platform folders.
When the project is opened on the laptop, Flutter can generate the Android
project with the installed SDK/Gradle configuration:

```bash
flutter create .
```

That creates the Android project without replacing the Dart `lib/` work.

## Native work queued for the laptop build
1. Android App Widget
2. Launcher shortcut
3. ACTION_SEND / Share Intent receiver
4. Notification/reminder support
5. Android permissions and exported-component configuration
6. Release signing configuration

## V1 principle
No server, login or cloud backend is required for these Android features.
