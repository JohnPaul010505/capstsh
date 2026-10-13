package com.example.fitness_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class GoalWidgetProvider : HomeWidgetProvider() {
  /**
   * `onEnabled` runs while the launcher is still binding the very first instance, and the
   * `home_widget` base implementation touches AlarmManager/PendingIntent there. Anything that
   * throws inside that window propagates back into the launcher's bind call, which surfaces to
   * the user as "Couldn't add widget" and aborts the whole add. Keep the plugin behaviour, but
   * never let an exception escape into the launcher.
   */
  override fun onEnabled(context: Context) {
    try {
      super.onEnabled(context)
    } catch (error: Throwable) {
      Log.w(TAG, "Goal widget onEnabled failed; continuing without rescheduling", error)
    }
  }

  override fun onDisabled(context: Context) {
    try {
      super.onDisabled(context)
    } catch (error: Throwable) {
      Log.w(TAG, "Goal widget onDisabled failed", error)
    }
  }

  /** Same protection for every other broadcast the system delivers to this provider. */
  override fun onReceive(context: Context, intent: Intent) {
    try {
      super.onReceive(context, intent)
    } catch (error: Throwable) {
      Log.w(TAG, "Goal widget onReceive failed for ${intent.action}", error)
    }
  }

  override fun onUpdate(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetIds: IntArray,
    widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      // A throw inside onUpdate reaches the launcher as a failed widget
      // update, which several launchers surface as "Couldn't add widget" and
      // which otherwise kills the whole add/refresh. Push the bare layout so
      // the widget still binds, and leave a logcat trace for diagnosis.
      try {
        appWidgetManager.updateAppWidget(widgetId, buildViews(context, widgetData))
      } catch (error: Exception) {
        Log.e(TAG, "Goal widget update failed for #$widgetId", error)
        try {
          appWidgetManager.updateAppWidget(
            widgetId,
            RemoteViews(context.packageName, R.layout.goal_widget),
          )
        } catch (fallbackError: Exception) {
          Log.e(TAG, "Goal widget fallback update failed for #$widgetId", fallbackError)
        }
      }
    }
  }

  private fun buildViews(
    context: Context,
    widgetData: SharedPreferences,
  ): RemoteViews {
    return RemoteViews(context.packageName, R.layout.goal_widget).apply {
        val openGoals = HomeWidgetLaunchIntent.getActivity(
          context,
          MainActivity::class.java,
          android.net.Uri.parse("triplejfitness:///member/goals"),
        )
        setOnClickPendingIntent(R.id.goal_widget_root, openGoals)

        val hasGoal = widgetData.getBoolean("goal_has_active", false)
        setTextViewText(
          R.id.goal_widget_title,
          widgetData.getString("goal_title", null) ?: "No active goal",
        )
        val current = widgetData.getString("goal_current", "\u2014") ?: "\u2014"
        val target = widgetData.getString("goal_target", "\u2014") ?: "\u2014"
        val remaining = widgetData.getString("goal_remaining", "\u2014") ?: "\u2014"
        val days = daysLeft(widgetData.getString("goal_end_date", "") ?: "")
        val progress = readProgressPercent(widgetData)
        setTextViewText(R.id.goal_widget_progress_text, if (hasGoal) "$progress% completed" else "Tap to create your first goal")
        setTextViewText(R.id.goal_widget_current, if (hasGoal) current else "\u2014")
        setTextViewText(R.id.goal_widget_target, if (hasGoal) target else "\u2014")
        setTextViewText(R.id.goal_widget_remaining, if (hasGoal) "$remaining to go" else "Set a goal")
        setTextViewText(R.id.goal_widget_days, if (hasGoal && days > 0) "$days days left" else "Keep going")

        // The ring always shows a percentage: the Flutter-rendered arc overlays the static
        // track when it is available, and the plain TextView below covers the fallback case so
        // the ring is never blank or clipped.
        setTextViewText(R.id.goal_widget_ring_pct, "$progress%")
        val ringPath = widgetData.getString("goal_progress_ring", null)
        val bitmap = ringPath?.takeIf { it.isNotBlank() }?.let { BitmapFactory.decodeFile(it) }
        if (hasGoal && bitmap != null) {
          setImageViewBitmap(R.id.goal_widget_ring, bitmap)
          setViewVisibility(R.id.goal_widget_ring, View.VISIBLE)
          setViewVisibility(R.id.goal_widget_ring_pct, View.GONE)
        } else {
          setViewVisibility(R.id.goal_widget_ring, View.GONE)
          setViewVisibility(R.id.goal_widget_ring_pct, View.VISIBLE)
        }
        setViewVisibility(R.id.goal_widget_ring_track, if (hasGoal) View.VISIBLE else View.GONE)
    }
  }

  companion object {
    private const val TAG = "GoalWidget"
  }

  private fun readProgressPercent(widgetData: SharedPreferences): Int {
    val isEncodedDouble = widgetData.getBoolean(
      "home_widget.double.goal_progress_pct",
      false,
    )
    val progress = if (isEncodedDouble) {
      val encoded = widgetData.getLong(
        "goal_progress_pct",
        java.lang.Double.doubleToRawLongBits(0.0),
      )
      java.lang.Double.longBitsToDouble(encoded)
    } else {
      (widgetData.all["goal_progress_pct"] as? Number)?.toDouble() ?: 0.0
    }
    return progress.toInt().coerceIn(0, 100)
  }

  private fun daysLeft(date: String): Int {
    if (date.isBlank()) return 0
    return try {
      val endDate = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply {
        isLenient = false
      }.parse(date) ?: return 0
      val end = Calendar.getInstance().apply {
        time = endDate
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
      }
      val today = Calendar.getInstance().apply {
        time = Date()
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
      }
      ((end.timeInMillis - today.timeInMillis) / 86_400_000L).toInt().coerceAtLeast(0)
    } catch (_: Exception) {
      0
    }
  }
}
