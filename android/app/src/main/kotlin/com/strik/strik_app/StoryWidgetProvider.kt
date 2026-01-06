package com.strik.strik_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class StoryWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                // Open App on Click
                // PendingIntent matches the one used by HomeWidget.
                // For now, let's rely on HomeWidget's default behavior if possible, or setup intent.
                // HomeWidgetProvider automatically handles simple data updates.
                
                // Update Text
                val title = widgetData.getString("widget_title", "Strik Momentz")
                val subtitle = widgetData.getString("widget_subtitle", "No new stories")
                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_subtitle, subtitle)

                // Update Image
                val imagePath = widgetData.getString("widget_image", null)
                if (imagePath != null) {
                    try {
                        val bitmap = BitmapFactory.decodeFile(imagePath)
                        setImageViewBitmap(R.id.widget_image, bitmap)
                        setViewVisibility(R.id.widget_image, View.VISIBLE)
                        setViewVisibility(R.id.widget_clock_icon, View.VISIBLE) // Show icon
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                } else {
                     // Hide Image View and Clock Icon if no story
                     setViewVisibility(R.id.widget_image, View.GONE) 
                     setViewVisibility(R.id.widget_clock_icon, View.GONE)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
