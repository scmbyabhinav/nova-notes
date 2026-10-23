#!/usr/bin/env python3
"""Patch the generated Android host with exact, spoken ORAH alarms."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "android" / "app" / "src" / "main"
MANIFEST = MAIN / "AndroidManifest.xml"
KOTLIN = MAIN / "kotlin" / "com" / "orah" / "orah_notes"
if not MANIFEST.exists():
    raise SystemExit("AndroidManifest.xml missing; run prepare_android_host.py first")
KOTLIN.mkdir(parents=True, exist_ok=True)

manifest = MANIFEST.read_text()
for permission in (
    "android.permission.SCHEDULE_EXACT_ALARM",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
    "android.permission.POST_NOTIFICATIONS",
):
    if permission not in manifest:
        manifest = manifest.replace(
            "<application",
            f'    <uses-permission android:name="{permission}" />\n    <application',
            1,
        )

service_decl = '''
        <service
            android:name=".OrahAlarmSpeechService"
            android:exported="false"
            android:foregroundServiceType="mediaPlayback" />
        <receiver
            android:name=".OrahAlarmReceiver"
            android:exported="false" />
'''
if "OrahAlarmSpeechService" not in manifest:
    manifest = manifest.replace("</application>", service_decl + "\n    </application>", 1)
MANIFEST.write_text(manifest)

activity = KOTLIN / "MainActivity.kt"
source = activity.read_text()
if "import android.app.PendingIntent" not in source:
    source = source.replace("import android.content.Context", "import android.app.PendingIntent\\nimport android.content.Context", 1)
marker = '        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)'
alarm_channel = '''
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "orah_notes/alarm")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleAlarm" -> {
                        val id = call.argument<String>("id")
                        val title = call.argument<String>("title")
                        val triggerAtMillis = call.argument<Long>("triggerAtMillis")
                        if (id.isNullOrBlank() || title.isNullOrBlank() || triggerAtMillis == null) {
                            result.error("invalid_alarm", "Alarm id, title, and time are required.", null)
                            return@setMethodCallHandler
                        }
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S &&
                            !alarmManager.canScheduleExactAlarms()) {
                            try {
                                startActivity(Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                                    .setData(android.net.Uri.parse("package:$packageName"))
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            } catch (_: Exception) { }
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val intent = Intent(this, OrahAlarmReceiver::class.java).apply {
                            action = "com.orah.orah_notes.ALARM"
                            putExtra("alarm_id", id)
                            putExtra("alarm_title", title)
                            setPackage(packageName)
                        }
                        val pending = PendingIntent.getBroadcast(
                            this, id.hashCode(), intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        val showIntent = PendingIntent.getActivity(
                            this, 0, Intent(this, MainActivity::class.java).setPackage(packageName),
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        alarmManager.setAlarmClock(
                            android.app.AlarmManager.AlarmClockInfo(triggerAtMillis, showIntent),
                            pending
                        )
                        result.success(true)
                    }
                    "cancelAlarm" -> {
                        val id = call.argument<String>("id")
                        if (!id.isNullOrBlank()) {
                            val intent = Intent(this, OrahAlarmReceiver::class.java).apply {
                                action = "com.orah.orah_notes.ALARM"
                                setPackage(packageName)
                            }
                            val pending = PendingIntent.getBroadcast(
                                this, id.hashCode(), intent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )
                            (getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager).cancel(pending)
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
'''
if '"orah_notes/alarm"' not in source:
    if marker not in source:
        raise SystemExit("Could not find MainActivity channel marker")
    source = source.replace(marker, alarm_channel + "\n" + marker, 1)
    activity.write_text(source)

(KOTLIN / "OrahAlarmReceiver.kt").write_text(r'''package com.orah.orah_notes

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.AlarmManager
import android.app.PendingIntent
import android.os.Build

class OrahAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra("alarm_id") ?: return
        val title = intent.getStringExtra("alarm_title") ?: "ORAH reminder"
        when (intent.action) {
            ACTION_SNOOZE -> {
                val stop = Intent(context, OrahAlarmSpeechService::class.java).setAction(OrahAlarmSpeechService.ACTION_STOP)
                context.startService(stop)
                val next = Intent(context, OrahAlarmReceiver::class.java).apply {
                    action = ACTION_ALARM
                    putExtra("alarm_id", id)
                    putExtra("alarm_title", title)
                    setPackage(context.packageName)
                }
                val pending = PendingIntent.getBroadcast(
                    context, id.hashCode(), next,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                manager.setAlarmClock(
                    AlarmManager.AlarmClockInfo(System.currentTimeMillis() + 10 * 60 * 1000L, pending),
                    pending
                )
            }
            else -> {
                val service = Intent(context, OrahAlarmSpeechService::class.java).apply {
                    putExtra("alarm_id", id)
                    putExtra("alarm_title", title)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(service)
                else context.startService(service)
            }
        }
    }

    companion object {
        const val ACTION_ALARM = "com.orah.orah_notes.ALARM"
        const val ACTION_SNOOZE = "com.orah.orah_notes.SNOOZE"
    }
}
''')

(KOTLIN / "OrahAlarmSpeechService.kt").write_text(r'''package com.orah.orah_notes

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.speech.tts.TextToSpeech
import java.util.Locale

class OrahAlarmSpeechService : Service(), TextToSpeech.OnInitListener {
    private var tts: TextToSpeech? = null
    private var ringtone: Ringtone? = null
    private var alarmTitle: String = "ORAH reminder"
    private var alarmId: String = "orah_alarm"

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopAlarm()
            return START_NOT_STICKY
        }
        alarmId = intent?.getStringExtra("alarm_id") ?: "orah_alarm"
        alarmTitle = intent?.getStringExtra("alarm_title")?.trim().takeUnless { it.isNullOrEmpty() }
            ?: "ORAH reminder"
        createChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            ringtone = RingtoneManager.getRingtone(applicationContext, uri)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                ringtone?.audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) ringtone?.isLooping = true
            ringtone?.play()
        } catch (_: Exception) { }
        if (tts == null) tts = TextToSpeech(applicationContext, this)
        return START_STICKY
    }

    override fun onInit(status: Int) {
        if (status != TextToSpeech.SUCCESS) return
        try {
            tts?.language = Locale.getDefault()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                tts?.speak(alarmTitle, TextToSpeech.QUEUE_FLUSH, null, "orah_alarm_title")
            } else {
                @Suppress("DEPRECATION")
                tts?.speak(alarmTitle, TextToSpeech.QUEUE_FLUSH, null)
            }
        } catch (_: Exception) { }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID, "ORAH spoken alarms", NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alarm notifications with spoken note titles"
                setSound(null, null)
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val stopIntent = Intent(this, OrahAlarmSpeechService::class.java).setAction(ACTION_STOP)
        val stop = PendingIntent.getService(
            this, 7001, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val snoozeIntent = Intent(this, OrahAlarmReceiver::class.java).apply {
            action = OrahAlarmReceiver.ACTION_SNOOZE
            putExtra("alarm_id", alarmId)
            putExtra("alarm_title", alarmTitle)
        }
        val snooze = PendingIntent.getBroadcast(
            this, alarmId.hashCode(), snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(alarmTitle)
            .setContentText("ORAH is speaking your reminder")
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_media_pause, "Stop", stop)
            .addAction(android.R.drawable.ic_lock_idle_alarm, "Snooze 10 min", snooze)
            .build()
    }

    private fun stopAlarm() {
        try { ringtone?.stop() } catch (_: Exception) { }
        try { tts?.stop() } catch (_: Exception) { }
        try { tts?.shutdown() } catch (_: Exception) { }
        tts = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        try { ringtone?.stop() } catch (_: Exception) { }
        try { tts?.stop() } catch (_: Exception) { }
        try { tts?.shutdown() } catch (_: Exception) { }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_STOP = "com.orah.orah_notes.STOP_ALARM"
        private const val CHANNEL_ID = "orah_spoken_alarms"
        private const val NOTIFICATION_ID = 7010
    }
}
''')

print("Added exact alarm bridge and spoken-alarm foreground service.")
