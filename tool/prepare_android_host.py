#!/usr/bin/env python3
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "android"
MAIN = ANDROID / "app" / "src" / "main"
MANIFEST = MAIN / "AndroidManifest.xml"
KOTLIN = MAIN / "kotlin" / "com" / "orah" / "orah_notes"
RES_XML = MAIN / "res" / "xml"
RES_LAYOUT = MAIN / "res" / "layout"

KOTLIN.mkdir(parents=True, exist_ok=True)
if not ANDROID.exists():
    raise SystemExit("Generated Android directory is missing.")

RES_XML.mkdir(parents=True, exist_ok=True)
RES_LAYOUT.mkdir(parents=True, exist_ok=True)
RES_VALUES = MAIN / "res" / "values"
RES_VALUES.mkdir(parents=True, exist_ok=True)

manifest = MANIFEST.read_text()
if not MANIFEST.exists():
    raise SystemExit("AndroidManifest.xml was not generated.")

# speech_to_text needs microphone access on Android. The host is generated
# during CI, so keep the permission in this preparation step rather than in
# a non-existent checked-in Android host.
if 'android.permission.USE_BIOMETRIC' not in manifest:
    manifest = manifest.replace(
        '<application',
        '    <uses-permission android:name="android.permission.USE_BIOMETRIC" />\\n    <application',
        1,
    )

if 'android.permission.RECORD_AUDIO' not in manifest:
    manifest = manifest.replace(
        '<application',
        '    <uses-permission android:name="android.permission.RECORD_AUDIO" />\\n    <application',
        1,
    )

# Note alarms need exact-alarm access where Android permits it, and a
# foreground media-playback service so the note title can be spoken while
# the Flutter process is backgrounded.
for permission in (
    "android.permission.SCHEDULE_EXACT_ALARM",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
):
    if permission not in manifest:
        manifest = manifest.replace(
            '<application',
            f'    <uses-permission android:name="{permission}" />\\n    <application',
            1,
        )


# Android 11+ package visibility requires the speech recognition service
# query so speech_to_text can discover the platform recognizer.
if 'android.speech.RecognitionService' not in manifest:
    manifest = manifest.replace(
        '</manifest>',
        '''    <queries>
        <intent>
            <action android:name="android.speech.RecognitionService" />
        </intent>
    </queries>
</manifest>''',
        1,
    )

manifest = manifest.replace('android:label="orah_notes"', 'android:label="@string/app_name"')
manifest = manifest.replace('android:label="Orah"', 'android:label="@string/app_name"')

# Android is generated in CI, so the canonical app display name lives here
# rather than in a checked-in android/app/src/main/res/values/strings.xml.
RES_VALUES.joinpath("strings.xml").write_text('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Orah Notes</string>
</resources>
''')

activity_marker = 'android:name=".MainActivity"'
if activity_marker not in manifest:
    raise SystemExit("MainActivity activity not found in AndroidManifest.xml")

# The share plugin requires a singleTask activity. Normalize any generated
# launchMode first so the manifest can never contain duplicate attributes.
import re
manifest = re.sub(r'\s+android:launchMode="[^"]*"', '', manifest)
manifest = manifest.replace(activity_marker, activity_marker + '\n            android:launchMode="singleTask"', 1)

share_filters = '''
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="text/*" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="image/*" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="*/*" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.SEND_MULTIPLE" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="image/*" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.SEND_MULTIPLE" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="*/*" />
            </intent-filter>
'''
if 'android.intent.action.SEND_MULTIPLE' not in manifest:
    manifest = manifest.replace('</activity>', share_filters + '        </activity>', 1)

shortcut_meta = '''
        <meta-data
            android:name="android.app.shortcuts"
            android:resource="@xml/orah_shortcuts" />
'''
if 'android:name="android.app.shortcuts"' not in manifest:
    # Android shortcut metadata belongs directly under <application>.
    manifest = manifest.replace('</application>', shortcut_meta + '    </application>', 1)

widget_receiver = '''
        <receiver
            android:name=".OrahQuickWidgetProvider"
            android:exported="false">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/orah_widget_info" />
        </receiver>
'''
if 'OrahQuickWidgetProvider' not in manifest:
    manifest = manifest.replace('</application>', widget_receiver + '    </application>', 1)

alarm_components = """
        <receiver
            android:name=".OrahAlarmReceiver"
            android:exported="false" />
        <receiver
            android:name=".OrahAlarmBootReceiver"
            android:enabled="true"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
            </intent-filter>
        </receiver>
        <service
            android:name=".OrahAlarmSpeechService"
            android:exported="false"
            android:foregroundServiceType="mediaPlayback" />
"""
if 'android:name=".OrahAlarmReceiver"' not in manifest:
    manifest = manifest.replace('</application>', alarm_components + '    </application>', 1)


MANIFEST.write_text(manifest)

(MAIN / "kotlin" / "com" / "orah" / "orah_notes" / "MainActivity.kt").write_text(r'''package com.orah.orah_notes

import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "orah_notes/android"
        const val ACTION_NEW_NOTE = "com.orah.orah_notes.NEW_NOTE"
        const val ACTION_NEW_CHECKLIST = "com.orah.orah_notes.NEW_CHECKLIST"
        const val ACTION_SEARCH = "com.orah.orah_notes.SEARCH"
        private const val PREFS = "orah_android_intents"
        private const val KEY_ACTION = "pending_action"
    }

    private var channel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        rememberIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "shareIntoOrah" -> {
                    val shareIntent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, "Shared from ORAH Android features")
                        setPackage(packageName)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    }
                    startActivity(shareIntent)
                    result.success(true)
                }
                "getLaunchAction" -> {
                    val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    val value = prefs.getString(KEY_ACTION, null)
                    prefs.edit().remove(KEY_ACTION).apply()
                    result.success(value)
                }
                "clearLaunchAction" -> {
                    getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(KEY_ACTION).apply()
                    result.success(null)
                }
                "scheduleAlarm" -> {
                    val id = call.argument<String>("id")
                    val title = call.argument<String>("title")
                    val atMillis = call.argument<Long>("atMillis")
                    if (id.isNullOrBlank() || title.isNullOrBlank() || atMillis == null) {
                        result.error("invalid_alarm", "Alarm id, title and time are required", null)
                    } else {
                        OrahAlarmScheduler.schedule(this, id, title, atMillis)
                        result.success(true)
                    }
                }
                "cancelAlarm" -> {
                    val id = call.arguments as? String
                    if (!id.isNullOrBlank()) OrahAlarmScheduler.cancel(this, id)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        rememberIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        rememberIntent(intent)
        val action = actionForIntent(intent) ?: return
        channel?.invokeMethod("launchAction", action)
    }

    private fun rememberIntent(intent: Intent?) {
        val action = actionForIntent(intent) ?: return
        getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ACTION, action)
            .apply()
    }

    private fun actionForIntent(intent: Intent?): String? = when (intent?.action) {
        ACTION_NEW_NOTE -> "new_note"
        ACTION_NEW_CHECKLIST -> "new_checklist"
        ACTION_SEARCH -> "search"
        else -> null
    }
}
''')

(MAIN / "kotlin" / "com" / "orah" / "orah_notes" / "OrahQuickWidgetProvider.kt").write_text(r'''package com.orah.orah_notes

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class OrahQuickWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.orah_quick_widget)
            views.setOnClickPendingIntent(
                R.id.orah_widget_note,
                pendingIntent(context, MainActivity.ACTION_NEW_NOTE, 1001)
            )
            views.setOnClickPendingIntent(
                R.id.orah_widget_checklist,
                pendingIntent(context, MainActivity.ACTION_NEW_CHECKLIST, 1002)
            )
            views.setOnClickPendingIntent(
                R.id.orah_widget_search,
                pendingIntent(context, MainActivity.ACTION_SEARCH, 1003)
            )
            manager.updateAppWidget(id, views)
        }
    }

    private fun pendingIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = action
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            setPackage(context.packageName)
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
''')

(RES_XML / "orah_widget_info.xml").write_text('''<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="250dp"
    android:minHeight="110dp"
    android:minResizeWidth="180dp"
    android:minResizeHeight="100dp"
    android:updatePeriodMillis="86400000"
    android:initialLayout="@layout/orah_quick_widget"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen" />
''')

(RES_LAYOUT / "orah_quick_widget.xml").write_text('''<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="12dp"
    android:background="#F8FAFC">
    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="ORAH"
        android:textStyle="bold"
        android:textSize="18sp"
        android:textColor="#0F172A"
        android:paddingBottom="8dp" />
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal">
        <Button
            android:id="@+id/orah_widget_note"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Note" />
        <Button
            android:id="@+id/orah_widget_checklist"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Checklist" />
        <Button
            android:id="@+id/orah_widget_search"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Search" />
    </LinearLayout>
</LinearLayout>
''')

# R8 sees optional ML Kit language recognizers referenced by the Flutter
# plugin even when those language-specific artifacts are not bundled.
# Suppress those optional missing-class warnings so release shrinking can finish.
(ANDROID / "app" / "proguard-rules.pro").write_text("""-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
""")

RES_VALUES.joinpath("orah_strings.xml").write_text('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="orah_shortcut_new_note_short">New note</string>
    <string name="orah_shortcut_new_note_long">Create a new ORAH note</string>
    <string name="orah_shortcut_new_checklist_short">New checklist</string>
    <string name="orah_shortcut_new_checklist_long">Create a new ORAH checklist</string>
    <string name="orah_shortcut_search_short">Search</string>
    <string name="orah_shortcut_search_long">Search ORAH</string>
</resources>
''')

(RES_XML / "orah_shortcuts.xml").write_text('''<?xml version="1.0" encoding="utf-8"?>
<shortcuts xmlns:android="http://schemas.android.com/apk/res/android">
    <shortcut
        android:shortcutId="new_note"
        android:enabled="true"
        android:icon="@mipmap/ic_launcher"
        android:shortcutShortLabel="@string/orah_shortcut_new_note_short"
        android:shortcutLongLabel="@string/orah_shortcut_new_note_long">
        <intent
            android:action="com.orah.orah_notes.NEW_NOTE"
            android:targetPackage="com.orah.orah_notes"
            android:targetClass="com.orah.orah_notes.MainActivity" />
    </shortcut>
    <shortcut
        android:shortcutId="new_checklist"
        android:enabled="true"
        android:icon="@mipmap/ic_launcher"
        android:shortcutShortLabel="@string/orah_shortcut_new_checklist_short"
        android:shortcutLongLabel="@string/orah_shortcut_new_checklist_long">
        <intent
            android:action="com.orah.orah_notes.NEW_CHECKLIST"
            android:targetPackage="com.orah.orah_notes"
            android:targetClass="com.orah.orah_notes.MainActivity" />
    </shortcut>
    <shortcut
        android:shortcutId="search"
        android:enabled="true"
        android:icon="@mipmap/ic_launcher"
        android:shortcutShortLabel="@string/orah_shortcut_search_short"
        android:shortcutLongLabel="@string/orah_shortcut_search_long">
        <intent
            android:action="com.orah.orah_notes.SEARCH"
            android:targetPackage="com.orah.orah_notes"
            android:targetClass="com.orah.orah_notes.MainActivity" />
    </shortcut>
</shortcuts>
''')

# flutter_local_notifications requires Java 8+ core library desugaring.
# Patch whichever Android Gradle DSL Flutter generated (Groovy or Kotlin).
for gradle_path in (ANDROID / "app" / "build.gradle", ANDROID / "app" / "build.gradle.kts"):
    if not gradle_path.exists():
        continue
    text = gradle_path.read_text()
    if gradle_path.suffix == ".kts":
        if "isCoreLibraryDesugaringEnabled" not in text:
            text = text.replace(
                "compileOptions {",
                "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
                1,
            )
        if 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:' not in text:
            text = text.replace(
                "dependencies {",
                'dependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")',
                1,
            )
    else:
        if "coreLibraryDesugaringEnabled" not in text:
            text = text.replace(
                "compileOptions {",
                "compileOptions {\n        coreLibraryDesugaringEnabled true",
                1,
            )
        if "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:" not in text:
            text = text.replace(
                "dependencies {",
                "dependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.5'",
                1,
            )
    gradle_path.write_text(text)
    print(f"Configured core library desugaring in {gradle_path}")

# Configure release shrinking so Play's release artifacts use R8/resource shrinking.
for gradle_path in (ANDROID / "app" / "build.gradle", ANDROID / "app" / "build.gradle.kts"):
    if not gradle_path.exists():
        continue
    text = gradle_path.read_text()
    if "buildTypes {" not in text or "release {" not in text:
        raise SystemExit(f"Release build type not found in {gradle_path}")
    if gradle_path.suffix == ".kts":
        if "isMinifyEnabled = true" not in text:
            text = text.replace("        release {", '        release {\n            isMinifyEnabled = true', 1)
        if "isShrinkResources = true" not in text:
            text = text.replace("        release {", '        release {\n            isShrinkResources = true', 1)
        if "getDefaultProguardFile" not in text:
            text = text.replace("        release {", '        release {\n            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")', 1)
    else:
        if "minifyEnabled true" not in text:
            text = text.replace("        release {", "        release {\n            minifyEnabled true", 1)
        if "shrinkResources true" not in text:
            text = text.replace("        release {", "        release {\n            shrinkResources true", 1)
        if "getDefaultProguardFile" not in text:
            text = text.replace("        release {", '        release {\n            proguardFiles getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro"', 1)
    gradle_path.write_text(text)
    print(f"Configured R8/resource shrinking in {gradle_path}")


# Firebase Analytics configuration is supplied in the repository because the
# Android host is generated from scratch in CI. The config contains client-side
# identifiers, not a service-account credential.
firebase_config = ROOT / "firebase" / "google-services.json"
if not firebase_config.is_file():
    raise SystemExit("Firebase config missing: firebase/google-services.json")
shutil.copyfile(firebase_config, ANDROID / "app" / "google-services.json")

# The Google Services Gradle plugin converts google-services.json into Android
# resources consumed by Firebase SDKs. Both Gradle DSLs are supported because
# Flutter may generate either file format depending on its template version.
settings_candidates = [ANDROID / "settings.gradle.kts", ANDROID / "settings.gradle"]
settings_gradle = next((path for path in settings_candidates if path.exists()), None)
app_gradle_candidates = [ANDROID / "app" / "build.gradle.kts", ANDROID / "app" / "build.gradle"]
app_gradle = next((path for path in app_gradle_candidates if path.exists()), None)
if settings_gradle is None or app_gradle is None:
    raise SystemExit("Generated Android Gradle settings/app file not found")

settings_text = settings_gradle.read_text()
if settings_gradle.suffix == ".kts":
    if 'id("com.google.gms.google-services") version' not in settings_text:
        if "plugins {" not in settings_text:
            raise SystemExit("Gradle plugins block not found in settings file")
        settings_text = settings_text.replace(
            "plugins {",
            'plugins {\n    id("com.google.gms.google-services") version "4.4.2" apply false',
            1,
        )
else:
    if 'id "com.google.gms.google-services" version' not in settings_text:
        if "plugins {" not in settings_text:
            raise SystemExit("Gradle plugins block not found in settings file")
        settings_text = settings_text.replace(
            "plugins {",
            'plugins {\n    id "com.google.gms.google-services" version "4.4.2" apply false',
            1,
        )
settings_gradle.write_text(settings_text)

app_text = app_gradle.read_text()
if app_gradle.suffix == ".kts":
    if 'id("com.google.gms.google-services")' not in app_text:
        if "plugins {" not in app_text:
            raise SystemExit("Gradle plugins block not found in app file")
        app_text = app_text.replace(
            "plugins {",
            'plugins {\n    id("com.google.gms.google-services")',
            1,
        )
else:
    if 'id "com.google.gms.google-services"' not in app_text:
        if "plugins {" not in app_text:
            raise SystemExit("Gradle plugins block not found in app file")
        app_text = app_text.replace(
            "plugins {",
            'plugins {\n    id "com.google.gms.google-services"',
            1,
        )
app_gradle.write_text(app_text)

# Validate generated AndroidManifest.xml is well-formed before Gradle sees it.
manifest = ANDROID / "app" / "src" / "main" / "AndroidManifest.xml"
if manifest.exists():
    import xml.etree.ElementTree as ET
    try:
        ET.parse(manifest)
    except ET.ParseError as exc:
        raise SystemExit(f"Generated AndroidManifest.xml is invalid: {exc}")

# Pin the generated Android host to Android 16 (API 36).
for gradle_path in (ANDROID / "app" / "build.gradle", ANDROID / "app" / "build.gradle.kts"):
    if not gradle_path.exists():
        continue
    text = gradle_path.read_text()
    if gradle_path.suffix == ".kts":
        import re
        text = re.sub(r"targetSdk\s*=\s*[^\n]+", "targetSdk = 36", text)
        text = re.sub(r"compileSdk\s*=\s*[^\n]+", "compileSdk = 36", text)
        if "targetSdk =" not in text:
            text = text.replace("android {", "android {\n    targetSdk = 36", 1)
        if "compileSdk =" not in text:
            text = text.replace("android {", "android {\n    compileSdk = 36", 1)
    else:
        import re
        text = re.sub(r"targetSdkVersion\s+[^\n]+", "targetSdkVersion 36", text)
        text = re.sub(r"compileSdkVersion\s+[^\n]+", "compileSdkVersion 36", text)
        if "targetSdkVersion 36" not in text:
            text = text.replace("android {", "android {\n    targetSdkVersion 36", 1)
        if "compileSdkVersion 36" not in text:
            text = text.replace("android {", "android {\n    compileSdkVersion 36", 1)
    gradle_path.write_text(text)



# Native alarm service is required because a Flutter callback cannot speak
# when Android has terminated the Dart isolate. It uses AlarmManager, Android
# TextToSpeech, and a foreground service; all alarm metadata remains on-device.
(KOTLIN / "OrahAlarmScheduler.kt").write_text(r'''package com.orah.orah_notes

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject

object OrahAlarmScheduler {
    private const val PREFS = "orah_alarm_speech"
    private const val PREFIX = "alarm_"

    fun schedule(context: Context, id: String, title: String, atMillis: Long) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().putString(PREFIX + id, JSONObject()
            .put("id", id).put("title", title).put("atMillis", atMillis).toString()).apply()
        schedulePending(context, id, title, atMillis)
    }

    fun cancel(context: Context, id: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent(context, id, "", 0L))
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(PREFIX + id).apply()
        context.sendBroadcast(Intent(context, OrahAlarmReceiver::class.java).apply {
            action = OrahAlarmReceiver.ACTION_STOP
            putExtra("id", id)
        })
    }

    fun restore(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.all.forEach { (key, value) ->
            if (key.startsWith(PREFIX) && value is String) {
                try {
                    val json = JSONObject(value)
                    val at = json.getLong("atMillis")
                    if (at > System.currentTimeMillis()) {
                        schedulePending(context, json.getString("id"), json.getString("title"), at)
                    } else {
                        prefs.edit().remove(key).apply()
                    }
                } catch (_: Exception) {
                    prefs.edit().remove(key).apply()
                }
            }
        }
    }

    private fun schedulePending(context: Context, id: String, title: String, atMillis: Long) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, OrahAlarmReceiver::class.java).apply {
            action = OrahAlarmReceiver.ACTION_FIRE
            putExtra("id", id)
            putExtra("title", title)
        }
        val pending = PendingIntent.getBroadcast(
            context, id.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !manager.canScheduleExactAlarms()) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pending)
        } else {
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pending)
        }
    }

    private fun pendingIntent(context: Context, id: String, title: String, atMillis: Long): PendingIntent {
        val intent = Intent(context, OrahAlarmReceiver::class.java).apply {
            action = OrahAlarmReceiver.ACTION_FIRE
            putExtra("id", id)
            putExtra("title", title)
            putExtra("atMillis", atMillis)
        }
        return PendingIntent.getBroadcast(
            context, id.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
''')

(KOTLIN / "OrahAlarmReceiver.kt").write_text(r'''package com.orah.orah_notes

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class OrahAlarmReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_FIRE = "com.orah.orah_notes.ALARM_FIRE"
        const val ACTION_STOP = "com.orah.orah_notes.ALARM_STOP"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra("id") ?: return
        if (intent.action == ACTION_STOP) {
            context.stopService(Intent(context, OrahAlarmSpeechService::class.java).putExtra("id", id))
            return
        }
        if (intent.action != ACTION_FIRE) return
        val service = Intent(context, OrahAlarmSpeechService::class.java)
            .putExtra("id", id)
            .putExtra("title", intent.getStringExtra("title") ?: "Your reminder")
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(service)
            else context.startService(service)
        } catch (_: Exception) {
            // The scheduled notification remains as a fallback if Android
            // prevents the foreground alarm service from starting.
        }
    }
}
''')

(KOTLIN / "OrahAlarmBootReceiver.kt").write_text(r'''package com.orah.orah_notes

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class OrahAlarmBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            OrahAlarmScheduler.restore(context)
        }
    }
}
''')

(KOTLIN / "OrahAlarmSpeechService.kt").write_text(r'''package com.orah.orah_notes

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.tts.TextToSpeech
import java.util.Locale

class OrahAlarmSpeechService : Service(), TextToSpeech.OnInitListener {
    private val handler = Handler(Looper.getMainLooper())
    private var tts: TextToSpeech? = null
    private var ringtone: Ringtone? = null
    private var title = "Your reminder"
    private var alarmId = ""
    private var stopped = false

    override fun onCreate() {
        super.onCreate()
        createChannel()
        tts = TextToSpeech(applicationContext, this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        alarmId = intent?.getStringExtra("id") ?: alarmId
        title = intent?.getStringExtra("title") ?: title
        if (alarmId.isBlank()) {
            stopSelf()
            return START_NOT_STICKY
        }
        startForeground(731204, buildNotification())
        startRingtone()
        handler.postDelayed({
            stopRingtone()
            speakTitle()
        }, 1800L)
        return START_STICKY
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts?.language = Locale.getDefault()
            if (!stopped) handler.postDelayed({ speakTitle() }, 2200L)
        }
    }

    private fun speakTitle() {
        if (stopped || title.isBlank()) return
        tts?.speak("Reminder. $title", TextToSpeech.QUEUE_FLUSH, null, "orah_alarm_$alarmId")
        // Repeat the title periodically until the user dismisses the alarm.
        handler.postDelayed({
            if (!stopped) {
                startRingtone()
                handler.postDelayed({
                    stopRingtone()
                    speakTitle()
                }, 1200L)
            }
        }, 30000L)
    }

    private fun startRingtone() {
        try {
            stopRingtone()
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            ringtone = RingtoneManager.getRingtone(applicationContext, uri)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                ringtone?.audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            }
            ringtone?.play()
        } catch (_: Exception) {}
    }

    private fun stopRingtone() {
        try { ringtone?.stop() } catch (_: Exception) {}
        ringtone = null
    }

    private fun buildNotification(): Notification {
        val stopIntent = Intent(this, OrahAlarmReceiver::class.java).apply {
            action = OrahAlarmReceiver.ACTION_STOP
            putExtra("id", alarmId)
        }
        val stopPending = PendingIntent.getBroadcast(
            this, alarmId.hashCode(), stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val openIntent = packageManager.getLaunchIntentForPackage(packageName)
        val openPending = openIntent?.let {
            PendingIntent.getActivity(this, 731205, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, "orah_alarm_speech")
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        builder.setSmallIcon(applicationInfo.icon)
            .setContentTitle("ORAH alarm")
            .setContentText(title)
            .setCategory(Notification.CATEGORY_ALARM)
            .setPriority(Notification.PRIORITY_MAX)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(android.R.drawable.ic_media_pause, "Dismiss", stopPending)
        if (openPending != null) builder.setContentIntent(openPending)
        return builder.build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "orah_alarm_speech", "ORAH spoken alarms", NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Audible reminders that speak the note title"
                setSound(null, null)
                enableVibration(true)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        stopped = true
        handler.removeCallbacksAndMessages(null)
        stopRingtone()
        tts?.stop()
        tts?.shutdown()
        tts = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
''')

print("ORAH Android host prepared: share target, shortcuts, quick widget.")
