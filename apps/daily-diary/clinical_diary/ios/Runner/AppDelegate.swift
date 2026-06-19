import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications auto-registers via GeneratedPluginRegistrant.
    // The UNUserNotificationCenter delegate is owned by firebase_messaging
    // (FlutterAppDelegate); scheduled local reminders fire in background/closed
    // via the OS regardless, so no extra delegate wiring is added here to avoid
    // conflicting with FCM.
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
