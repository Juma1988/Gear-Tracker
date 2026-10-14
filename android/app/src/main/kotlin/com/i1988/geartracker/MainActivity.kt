package com.i1988.geartracker

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "gear_tracker/reminders"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "cancelScheduledReminders") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            // flutter_local_notifications owns the scheduled PendingIntents.
            // Its Dart-side cancel calls are the source of truth; this native
            // hook only clears legacy alarms created by older app versions.
            val alarmManager = getSystemService(AlarmManager::class.java)
            val intent = Intent(this, com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver::class.java)
            for (id in call.argument<List<Int>>("ids").orEmpty()) {
                val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
                val pendingIntent = PendingIntent.getBroadcast(this, id, intent, flags)
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
            }
            result.success(null)
        }
    }
}
