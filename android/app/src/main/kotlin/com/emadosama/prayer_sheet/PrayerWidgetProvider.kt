package com.emadosama.prayer_sheet

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * The home screen widget: today's five prayers, each one a tap away from being
 * logged.
 *
 * Everything drawn here is written by the Dart side first; this class only
 * reads those values back, because a widget cannot reach into the app.
 */
class PrayerWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.prayer_widget)

            views.setTextViewText(
                R.id.widget_count,
                widgetData.getString("count", "0/5"),
            )
            views.setTextViewText(
                R.id.widget_date,
                widgetData.getString("date", ""),
            )

            // Empty when there is no streak: a "0 days" badge would be a
            // reproach rather than an encouragement.
            val streak = widgetData.getString("streak", "").orEmpty()
            views.setTextViewText(R.id.widget_streak, streak)
            views.setViewVisibility(
                R.id.widget_streak,
                if (streak.isEmpty()) View.GONE else View.VISIBLE,
            )

            val current = widgetData.getString("current", "")
            PRAYERS.forEach { (id, viewId) ->
                bindPrayer(context, views, widgetData, id, viewId, current)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun bindPrayer(
        context: Context,
        views: RemoteViews,
        widgetData: SharedPreferences,
        id: String,
        viewId: Int,
        current: String?,
    ) {
        val isDone = widgetData.getBoolean("done_$id", false)

        views.setTextViewText(viewId, widgetData.getString("name_$id", id))
        views.setInt(
            viewId,
            "setBackgroundResource",
            when {
                isDone -> R.drawable.widget_pill_done
                id == current -> R.drawable.widget_pill_current
                else -> R.drawable.widget_pill
            },
        )
        views.setTextColor(
            viewId,
            context.getColor(
                if (isDone) R.color.widget_text_done else R.color.widget_text,
            ),
        )

        // Logging happens without opening the app: the tap wakes a background
        // Dart isolate, which writes to the same log the app reads.
        views.setOnClickPendingIntent(
            viewId,
            HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("prayersheet://log?prayer=$id"),
            ),
        )
    }

    private companion object {
        val PRAYERS = listOf(
            "fajr" to R.id.prayer_fajr,
            "dhuhr" to R.id.prayer_dhuhr,
            "asr" to R.id.prayer_asr,
            "maghrib" to R.id.prayer_maghrib,
            "isha" to R.id.prayer_isha,
        )
    }
}
