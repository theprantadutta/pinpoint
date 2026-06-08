package com.pranta.pinpoint

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    // Create the high-importance notification channel NATIVELY, on every
    // launch, before any Dart code runs. The Dart side
    // (FirebaseNotificationService) also creates this channel — but only once
    // the user reaches the home screen and init completes. Until then a fresh
    // install (or cleared-data / new device) has NO channel, and an FCM push
    // that targets "pinpoint_default_channel" on Android 8+ is silently dropped
    // or demoted by the system. Creating it here guarantees the channel exists
    // from the first millisecond of app life. createNotificationChannel is
    // idempotent (same id -> no-op), so the later Dart creation is harmless.
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = getString(R.string.default_notification_channel_id)
            val name = getString(R.string.default_notification_channel_name)
            val descriptionText = getString(R.string.default_notification_channel_desc)
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(channelId, name, importance).apply {
                description = descriptionText
                enableVibration(true)
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}
