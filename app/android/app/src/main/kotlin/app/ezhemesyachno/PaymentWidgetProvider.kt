package app.ezhemesyachno

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Домашний виджет: «сколько платить в этом месяце» и три ближайших платежа.
 *
 * Данные приходят из кэша `widget_data.json`, который пишет Dart-сторона
 * (см. `FileWidgetCacheWriter`); здесь только чтение и рендер, без дублирования
 * логики расписания.
 */
class PaymentWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context))
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        updateAll(context)
    }

    companion object {
        const val FILE_NAME = "widget_data.json"

        /** Вызывается из MainActivity, когда Dart записал новый кэш. */
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, PaymentWidgetProvider::class.java),
            )
            for (id in ids) {
                manager.updateAppWidget(id, buildViews(context))
            }
        }

        private fun loadData(context: Context): JSONObject? {
            val file = File(context.filesDir, FILE_NAME)
            if (!file.exists()) return null
            return try {
                JSONObject(file.readText(Charsets.UTF_8))
            } catch (_: Exception) {
                null
            }
        }

        private fun buildViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.payment_widget)
            val data = loadData(context)

            if (data == null || data.optBoolean("isEmpty", true)) {
                views.setViewVisibility(R.id.widget_month_total, View.GONE)
                views.setViewVisibility(R.id.widget_note, View.GONE)
                views.setViewVisibility(R.id.widget_divider, View.GONE)
                views.setViewVisibility(R.id.row1, View.GONE)
                views.setViewVisibility(R.id.row2, View.GONE)
                views.setViewVisibility(R.id.row3, View.GONE)
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_empty, View.GONE)
                views.setViewVisibility(R.id.widget_divider, View.VISIBLE)
                views.setTextViewText(
                    R.id.widget_month_total,
                    data.optString("monthTotalLabel", ""),
                )
                views.setTextViewText(R.id.widget_note, data.optString("noteLabel", ""))
                val payments = data.optJSONArray("payments")
                bindRow(views, R.id.row1, R.id.row1_dot, R.id.row1_name, R.id.row1_due, R.id.row1_amount, payments, 0)
                bindRow(views, R.id.row2, R.id.row2_dot, R.id.row2_name, R.id.row2_due, R.id.row2_amount, payments, 1)
                bindRow(views, R.id.row3, R.id.row3_dot, R.id.row3_name, R.id.row3_due, R.id.row3_amount, payments, 2)
            }

            // Нажатие на виджет открывает приложение.
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                val pending = PendingIntent.getActivity(
                    context,
                    0,
                    launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_root, pending)
            }
            return views
        }

        private fun bindRow(
            views: RemoteViews,
            rowId: Int,
            dotId: Int,
            nameId: Int,
            dueId: Int,
            amountId: Int,
            payments: JSONArray?,
            index: Int,
        ) {
            if (payments == null || index >= payments.length()) {
                views.setViewVisibility(rowId, View.GONE)
                return
            }
            val payment = payments.optJSONObject(index) ?: run {
                views.setViewVisibility(rowId, View.GONE)
                return
            }
            views.setViewVisibility(rowId, View.VISIBLE)
            views.setTextViewText(nameId, payment.optString("name", ""))
            views.setTextViewText(dueId, payment.optString("dueLabel", ""))
            val amount = payment.optString("amountLabel", "")
            views.setTextViewText(amountId, if (amount.isEmpty()) "сумма меняется" else amount)

            val colorHex = payment.optString("colorHex", "")
            if (colorHex.isNotEmpty()) {
                try {
                    views.setInt(dotId, "setBackgroundColor", Color.parseColor(colorHex))
                } catch (_: IllegalArgumentException) {
                    // Некорректный цвет — оставляем белый по умолчанию.
                }
            }
        }
    }
}
