#!/usr/bin/env python3
from pathlib import Path

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


manifest = manifest.replace('android:label="orah_notes"', 'android:label="ORAH"')
manifest = manifest.replace('android:label="Orah"', 'android:label="ORAH"')

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

# Validate generated AndroidManifest.xml is well-formed before Gradle sees it.
manifest = ANDROID / "app" / "src" / "main" / "AndroidManifest.xml"
if manifest.exists():
    import xml.etree.ElementTree as ET
    try:
        ET.parse(manifest)
    except ET.ParseError as exc:
        raise SystemExit(f"Generated AndroidManifest.xml is invalid: {exc}")

print("ORAH Android host prepared: share target, shortcuts, quick widget.")
