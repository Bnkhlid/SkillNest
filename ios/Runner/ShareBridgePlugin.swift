import Flutter
import UIKit

/// Delivers a link saved by the iOS Share Extension to Flutter.
final class ShareBridgePlugin: NSObject, FlutterPlugin {
  static let appGroup = "group.com.learningvault.learningVault"
  static let sharedTextKey = "skillnest.sharedText"
  private(set) static var shared: ShareBridgePlugin?
  private var channel: FlutterMethodChannel?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.skillnest.app/share",
      binaryMessenger: registrar.messenger()
    )
    let instance = ShareBridgePlugin()
    instance.channel = channel
    Self.shared = instance
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
    case "shareText":
      guard let args = call.arguments as? [String: Any],
            let text = args["text"] as? String, !text.isEmpty else {
        result(FlutterError(code: "INVALID_TEXT", message: "Text is empty", details: nil))
        return
      }
      let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
      if let rootVC = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? UIApplication.shared.windows.first?.rootViewController {
        if let popover = activityVC.popoverPresentationController {
          popover.sourceView = rootVC.view
          popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
          popover.permittedArrowDirections = []
        }
        rootVC.present(activityVC, animated: true) {
          result(true)
        }
      } else {
        result(false)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Checks if there is pending shared text and dispatches it over the channel if available.
  @discardableResult
  static func checkAndDispatchPendingShare() -> Bool {
    let defaults = UserDefaults(suiteName: appGroup)
    if let text = defaults?.string(forKey: sharedTextKey), !text.isEmpty {
      defaults?.removeObject(forKey: sharedTextKey)
      shared?.channel?.invokeMethod("onSharedTextReceived", arguments: text)
      return true
    }
    return false
  }

  /// Handles incoming custom URL scheme (e.g., skillnest://shared).
  @discardableResult
  static func handleIncomingUrl(_ url: URL) -> Bool {
    guard url.scheme?.lowercased() == "skillnest" else { return false }
    return checkAndDispatchPendingShare()
  }

  /// The share extension opens skillnest://shared after saving its payload.
  /// When the app was already running without scenes, forward it directly to Flutter.
  func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    return Self.handleIncomingUrl(url)
  }
}
