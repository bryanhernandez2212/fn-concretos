package com.fnconcretos.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Android 16's "Live Update" promoted notification
 * (https://developer.android.com/develop/ui/views/notifications/live-update)
 * for RouteNavigationScreen (Dart) — the DiDi/Uber-style lock-screen/
 * status-bar card, separate from google_navigation_flutter's own plain
 * foreground-service notification (which the SDK already posts on its own
 * and this app doesn't control).
 *
 * Every call here is safe on any OS version: NotificationCompat.ProgressStyle
 * and Builder#setRequestPromotedOngoing (androidx.core 1.16+) are ordinary
 * compat APIs — on a device/OS that doesn't support promotion (anything
 * before Android 16, or a user who hasn't enabled "Live updates" for this
 * app under system Settings — see Settings.ACTION_APP_NOTIFICATION_PROMOTION_SETTINGS,
 * not wired up here since it's not this screen's job to send the driver to
 * a settings screen), this just posts as an ordinary, non-promoted
 * notification instead of failing.
 */
object NavigationLiveUpdateManager {
    private const val CHANNEL_ID = "navigation_live_update"
    private const val CHANNEL_NAME = "Ruta en curso"
    private const val NOTIFICATION_ID = 4821

    /// First remaining-distance reading seen since [start] — treated as the
    /// route's total for computing a 0-100 progress percentage, same
    /// "first reading is the baseline" idiom as
    /// `direccion/route_eta.dart`'s RouteEtaTracker on the Dart side.
    private var totalDistanceMetros: Double? = null

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        // IMPORTANCE_MIN is explicitly disqualified from promotion per the
        // Android docs — DEFAULT is the lowest importance that still
        // qualifies.
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_DEFAULT)
        )
    }

    /// Posts the initial notification, indeterminate (no route progress
    /// known yet) until the first [update] call. [remisionId] (when known —
    /// the app never creates a Remisión itself, so it can be null) is
    /// embedded in the tap intent so tapping the notification can deep-link
    /// back to that delivery (see [contentIntentFor]).
    fun start(context: Context, folio: String, destino: String, remisionId: Int?) {
        totalDistanceMetros = null
        post(context, folio, destino, remisionId, remainingDistanceMetros = null, remainingTimeSeconds = null)
    }

    /// Called repeatedly as the drive progresses (see
    /// GoogleMapsNavigator.setOnRemainingTimeOrDistanceChangedListener on
    /// the Dart side) to move the progress bar and refresh the ETA.
    fun update(
        context: Context,
        folio: String,
        destino: String,
        remisionId: Int?,
        remainingDistanceMetros: Double,
        remainingTimeSeconds: Double,
    ) {
        val total = totalDistanceMetros
        if (total == null || remainingDistanceMetros > total) {
            // First reading, or the driver got rerouted further away than
            // the original estimate — reset the "100%" reference point
            // rather than showing a nonsensical negative/over-100% bar.
            totalDistanceMetros = remainingDistanceMetros
        }
        post(context, folio, destino, remisionId, remainingDistanceMetros, remainingTimeSeconds)
    }

    /// Called on arrival, or if the driver exits navigation early
    /// ([RouteNavigationScreen.dispose]) — nothing left to show progress
    /// for either way.
    fun stop(context: Context) {
        totalDistanceMetros = null
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    private fun post(
        context: Context,
        folio: String,
        destino: String,
        remisionId: Int?,
        remainingDistanceMetros: Double?,
        remainingTimeSeconds: Double?,
    ) {
        ensureChannel(context)

        val progressStyle = NotificationCompat.ProgressStyle()
        val total = totalDistanceMetros
        if (remainingDistanceMetros != null && total != null && total > 0) {
            val avanzadoPercent = ((total - remainingDistanceMetros) / total * 100)
                .toInt()
                .coerceIn(0, 100)
            progressStyle.setProgress(avanzadoPercent)
        } else {
            progressStyle.setProgressIndeterminate(true)
        }

        // Without this, tapping the notification does nothing — Android
        // doesn't default to reopening the app on a bare notify() call, it
        // needs an explicit intent. FLAG_ACTIVITY_REORDER_TO_FRONT brings
        // the app's existing task forward instead of relaunching over it if
        // it's already open (e.g. paused behind the lock screen) — but if
        // Android already killed that task's Activity in the background
        // (common on some OEM skins), this still ends up as a cold start,
        // landing on whatever screen `main.dart` normally opens to rather
        // than back in this delivery; that's what `remisionId`
        // (`MainActivity.EXTRA_REMISION_ID`) is for — `MainActivity`
        // forwards it to Dart (`NavigationLiveUpdate`) either via
        // `onNewIntent` (app was still running) or a cold-start query, so
        // it can deep-link into `DeliveryDetailScreen` either way.
        val tapIntent = Intent(context, MainActivity::class.java)
            .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        if (remisionId != null) {
            tapIntent.putExtra(MainActivity.EXTRA_REMISION_ID, remisionId)
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            0,
            tapIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_directions)
            .setOngoing(true)
            .setRequestPromotedOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentTitle("Entrega $folio en camino")
            .setContentText(destino)
            .setContentIntent(contentIntent)
            .setStyle(progressStyle)

        if (remainingTimeSeconds != null) {
            val minutos = (remainingTimeSeconds / 60).toInt().coerceAtLeast(0)
            builder
                .setShortCriticalText("$minutos min")
                .setWhen(System.currentTimeMillis() + (remainingTimeSeconds * 1000).toLong())
                .setUsesChronometer(true)
                .setChronometerCountDown(true)
        }

        val notificationManager = NotificationManagerCompat.from(context)
        // On API 33+, notify() without POST_NOTIFICATIONS granted throws a
        // SecurityException rather than silently no-oping — this app
        // already asks for that permission at login (see
        // OneSignalService.requestPushPermission), but a driver who denied
        // it (or hasn't logged in through that path yet) shouldn't crash
        // navigation over a missing "nice to have" notification.
        if (notificationManager.areNotificationsEnabled()) {
            notificationManager.notify(NOTIFICATION_ID, builder.build())
        }
    }
}
