import Flutter
import GoogleMaps
import GoogleNavigation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // REQUIRED for the map/navigation in
    // lib/deliveries/route_navigation_screen.dart to work on iOS: needs
    // "Maps SDK for iOS" AND "Navigation SDK for iOS" enabled on this key
    // in Google Cloud Console. The Navigation SDK is billed separately
    // from Maps SDK — check current pricing before relying on this in
    // production.
    GMSServices.provideAPIKey("AIzaSyDp4VbFAq1b6Qc6KZgLnV1tc8kqWz1UFEg")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
