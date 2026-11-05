package com.pranta.pinpoint

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.core.content.IntentCompat
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
        const val CAPTURE_CHANNEL = "com.pranta.pinpoint/capture"

        // The extra the quick_actions plugin reads the shortcut type from.
        const val SHORTCUT_EXTRA = "some unique action key"
    }

    private var captureReady = false
    private var heldIntent: Intent? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        // Saved state means Android is rebuilding a killed app, and this is the
        // intent of the old launch: acting on it would repeat that share or
        // shortcut.
        if (savedInstanceState != null) intent?.let(::forgetCapture)
        intent?.let(::dropUnreadableShares)
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    override fun onNewIntent(intent: Intent) {
        dropUnreadableShares(intent)
        // On a rebuild this lands before Dart is listening, and the plugins
        // would drop it. It is passed on once Dart says it is ready.
        if (!captureReady) {
            heldIntent = intent
            return
        }
        super.onNewIntent(intent)
    }

    private fun forgetCapture(intent: Intent) {
        intent.action = Intent.ACTION_MAIN
        intent.type = null
        intent.removeExtra(Intent.EXTRA_STREAM)
        intent.removeExtra(Intent.EXTRA_TEXT)
        intent.removeExtra(SHORTCUT_EXTRA)
    }

    /**
     * The sharing plugin copies shared files on the main thread and does not
     * catch a refused read, so a sender that shares a file without granting
     * access would crash the app. Those files are removed first.
     */
    private fun dropUnreadableShares(intent: Intent) {
        when (intent.action) {
            Intent.ACTION_SEND -> {
                val uri = IntentCompat.getParcelableExtra(
                    intent, Intent.EXTRA_STREAM, Uri::class.java
                )
                if (uri != null && !canRead(uri)) intent.removeExtra(Intent.EXTRA_STREAM)
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = IntentCompat.getParcelableArrayListExtra(
                    intent, Intent.EXTRA_STREAM, Uri::class.java
                ) ?: return
                intent.putParcelableArrayListExtra(
                    Intent.EXTRA_STREAM, ArrayList(uris.filter(::canRead))
                )
            }
        }
    }

    private fun canRead(uri: Uri): Boolean = try {
        contentResolver.openInputStream(uri)?.close()
        true
    } catch (e: Exception) {
        false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAPTURE_CHANNEL)
            .setMethodCallHandler { _, result ->
                captureReady = true
                heldIntent?.let { held ->
                    heldIntent = null
                    onNewIntent(held)
                }
                result.success(null)
            }
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
