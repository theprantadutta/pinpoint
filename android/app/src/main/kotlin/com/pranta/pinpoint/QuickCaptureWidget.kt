package com.pranta.pinpoint

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Three buttons that open a new note, checklist or voice note. Each one sends
 * the same intent as the app shortcut, so it lands in CaptureInbox and waits
 * for sign-in and the unlock screen. It shows no note content: anything drawn
 * here would sit outside the encrypted database.
 */
class QuickCaptureWidget : AppWidgetProvider() {
    private companion object {
        // The extra the quick_actions plugin reads the shortcut type from.
        const val SHORTCUT_EXTRA = "some unique action key"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val views = RemoteViews(context.packageName, R.layout.quick_capture_widget)
        views.setOnClickPendingIntent(R.id.widget_note, open(context, 1, "new_note"))
        views.setOnClickPendingIntent(R.id.widget_checklist, open(context, 2, "new_checklist"))
        views.setOnClickPendingIntent(R.id.widget_voice, open(context, 3, "new_voice"))
        appWidgetManager.updateAppWidget(appWidgetIds, views)
    }

    private fun open(context: Context, requestCode: Int, shortcut: String): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction(Intent.ACTION_RUN)
            .putExtra(SHORTCUT_EXTRA, shortcut)
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
