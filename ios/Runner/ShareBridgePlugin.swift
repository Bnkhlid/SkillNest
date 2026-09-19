import Flutter
import UIKit

/// Delivers a link saved by the iOS Share Extension to Flutter.
final class ShareBridgePlugin: NSObject, FlutterPlugin {
  private static let appGroup = "group.com.learningvault.learningVault"
  private static let sharedTextKey = "skillnest.sharedText"
  private var channel: FlutterMethodChannel?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.skillnest.app/share",
      binaryMessenger: registrar.messenger()
    )
    let instance = ShareBridgePlugin()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getInitialSharedText":
      let defaults = UserDefaults(suiteName: Self.appGroup)
      let text = defaults?.string(forKey: Self.sharedTextKey)
      defaults?.removeObject(forKey: Self.sharedTextKey)
      result(text)
    case "clearSharedText":
      UserDefaults(suiteName: Self.appGroup)?.removeObject(forKey: Self.sharedTextKey)
      result(nil)
    case "openUrl":
      guard let args = call.arguments as? [String: Any],
            let rawUrl = args["url"] as? String,
            let url = URL(string: rawUrl) else {
        result(FlutterError(code: "INVALID_URL", message: "URL is empty or invalid", details: nil))
        return
      }
      UIApplication.shared.open(url, options: [:]) { result($0) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// The share extension opens skillnest://shared after saving its payload.
  /// When the app was already running, forward it directly to Flutter so the
  /// Add Resource screen opens just like it does on a cold start.
  func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    guard url.scheme?.lowercased() == "skillnest" else { return false }
    if let text = UserDefaults(suiteName: Self.appGroup)?.string(forKey: Self.sharedTextKey) {
      channel?.invokeMethod("onSharedTextReceived", arguments: text)
    }
    return true
  }
}
