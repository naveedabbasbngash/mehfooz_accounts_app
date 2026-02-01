import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {

  private let channelName = "icloud_file_access"
  private var methodChannel: FlutterMethodChannel?

  override func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    GeneratedPluginRegistrant.register(with: self)

    // 🔥 Delay channel setup until FlutterViewController is ready
    DispatchQueue.main.async {
      if let controller = self.window?.rootViewController as? FlutterViewController {
        self.methodChannel = FlutterMethodChannel(
            name: self.channelName,
            binaryMessenger: controller.binaryMessenger
        )

        self.methodChannel?.setMethodCallHandler { call, result in
          if call.method == "copyFromICloud" {
            guard let path = call.arguments as? String else {
              result(nil)
              return
            }

            let url = URL(fileURLWithPath: path)

            guard url.startAccessingSecurityScopedResource() else {
              result(nil)
              return
            }

            defer { url.stopAccessingSecurityScopedResource() }

            do {
              let docs = FileManager.default.urls(
                  for: .documentDirectory,
                  in: .userDomainMask
              ).first!

              let destURL = docs.appendingPathComponent(url.lastPathComponent)

              if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
              }

              try FileManager.default.copyItem(at: url, to: destURL)
              result(destURL.path)
            } catch {
              result(nil)
            }
          }
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
      _ application: UIApplication,
      open url: URL,
      options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {

    NSLog("📂 OPEN URL RECEIVED: \(url.absoluteString)")

    methodChannel?.invokeMethod(
        "onFileReceived",
        arguments: url.absoluteString
    )

    return true
  }
}