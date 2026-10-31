import Flutter
import UIKit

public class AppIconPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "app_icon", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(AppIconPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "supported":
      result(UIApplication.shared.supportsAlternateIcons)
    case "set":
      guard UIApplication.shared.supportsAlternateIcons else {
        result(false)
        return
      }
      let name = call.arguments as? String
      if UIApplication.shared.alternateIconName == name {
        result(true)
        return
      }
      UIApplication.shared.setAlternateIconName(name) { error in
        DispatchQueue.main.async { result(error == nil) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
