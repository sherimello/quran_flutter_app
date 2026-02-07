package com.example.quran_flutter_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class QuranWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            // Load the image from Flutter
            val imagePath = widgetData.getString("widget_image_path", null)
            if (imagePath != null && imagePath.isNotEmpty()) {
                val imageFile = File(imagePath)
                if (imageFile.exists()) {
                    try {
                        val bitmap = BitmapFactory.decodeFile(imagePath)
                        if (bitmap != null) {
                            views.setImageViewBitmap(R.id.widget_image, bitmap)
                        } else {
                             android.util.Log.e("QuranWidget", "Failed to decode bitmap from: $imagePath")
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("QuranWidget", "Error loading image: ${e.message}")
                    }
                }
            }

            // Click to launch app
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
