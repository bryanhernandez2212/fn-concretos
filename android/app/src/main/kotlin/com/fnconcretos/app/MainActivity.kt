package com.fnconcretos.app

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// local_auth (Face ID/Touch ID/biometría) requires a FragmentActivity to
// host its authentication prompt — FlutterActivity alone can't.
class MainActivity : FlutterFragmentActivity() {
    // Backs lib/deliveries/navigation_live_update.dart, which talks to
    // NavigationLiveUpdateManager.kt for the Android 16 "Live Update"
    // lock-screen/status-bar card while RouteNavigationScreen is
    // navigating — no Flutter/Dart wrapper exists for that native-only
    // notification API, unlike the rest of this app's Android integration
    // (which all goes through pub.dev packages).
    private val liveUpdateChannel = "fn_concretos/navigation_live_update"
    private var channel: MethodChannel? = null

    // Set from the launch Intent in configureFlutterEngine (cold start) and
    // consumed once by Dart's "consumeLaunchRemisionId" query — see
    // EXTRA_REMISION_ID below for why this exists at all.
    private var pendingLaunchRemisionId: Int? = null

    companion object {
        // Embedded by NavigationLiveUpdateManager.kt on the Live Update
        // notification's tap intent so tapping it can deep-link back into
        // that delivery (DeliveryDetailScreen), not just reopen the app
        // generically — see the two branches below for why both a cold-start
        // query AND an onNewIntent push are needed to cover it reliably.
        const val EXTRA_REMISION_ID = "remisionId"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, liveUpdateChannel)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    NavigationLiveUpdateManager.start(
                        applicationContext,
                        call.argument<String>("folio") ?: "",
                        call.argument<String>("destino") ?: "",
                        call.argument<Int>("remisionId"),
                    )
                    result.success(null)
                }
                "update" -> {
                    NavigationLiveUpdateManager.update(
                        applicationContext,
                        call.argument<String>("folio") ?: "",
                        call.argument<String>("destino") ?: "",
                        call.argument<Int>("remisionId"),
                        call.argument<Double>("remainingDistanceMetros") ?: 0.0,
                        call.argument<Double>("remainingTimeSeconds") ?: 0.0,
                    )
                    result.success(null)
                }
                "stop" -> {
                    NavigationLiveUpdateManager.stop(applicationContext)
                    result.success(null)
                }
                "consumeLaunchRemisionId" -> {
                    // Cold start only: the Activity that's running right now
                    // was *created* from the notification's Intent, so this
                    // is the sole opportunity to read it — consumed (cleared)
                    // so a later hot-restart/rebuild doesn't re-trigger the
                    // same navigation.
                    result.success(pendingLaunchRemisionId)
                    pendingLaunchRemisionId = null
                }
                else -> result.notImplemented()
            }
        }

        // Cold start: this Activity instance was just created, possibly by
        // tapping the Live Update notification — capture that now, since
        // Dart isn't necessarily listening yet at this exact point (its
        // widget tree may not have built), so it asks for this later via
        // "consumeLaunchRemisionId" once it's ready, rather than racing a
        // push from here.
        val extraId = intent?.getIntExtra(EXTRA_REMISION_ID, -1) ?: -1
        pendingLaunchRemisionId = extraId.takeIf { it >= 0 }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Warm resume: this Activity was already running (launchMode
        // singleTop), so Dart is definitely already up and its handler
        // already registered — push directly instead of Dart having to poll
        // for something that, in this branch, was never going to arrive via
        // "consumeLaunchRemisionId" (that only reflects the *original*
        // launch Intent, not this new one).
        val extraId = intent.getIntExtra(EXTRA_REMISION_ID, -1)
        if (extraId >= 0) {
            channel?.invokeMethod("onNotificationTap", mapOf("remisionId" to extraId))
        }
    }
}
