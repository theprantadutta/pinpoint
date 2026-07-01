package com.pranta.pinpoint

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterFragmentActivity() {
    private companion object {
        const val OCR_CHANNEL = "com.pranta.pinpoint/ocr"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OCR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "recognizeText" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("bad_args", "Missing 'path' argument", null)
                        } else {
                            recognizeText(path, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // On-device OCR via Google ML Kit (Latin script). Replaces the
    // google_mlkit_text_recognition Flutter plugin, which is now handled
    // natively so iOS can use Apple Vision instead.
    private fun recognizeText(path: String, result: MethodChannel.Result) {
        try {
            val image = InputImage.fromFilePath(this, Uri.fromFile(File(path)))
            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            recognizer.process(image)
                .addOnSuccessListener { visionText ->
                    result.success(visionText.text)
                    recognizer.close()
                }
                .addOnFailureListener { e ->
                    result.error("ocr_failed", e.localizedMessage, null)
                    recognizer.close()
                }
        } catch (e: Exception) {
            result.error("ocr_failed", e.localizedMessage, null)
        }
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
