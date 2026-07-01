import Flutter
import UIKit
import UserNotifications
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure notification center delegate for iOS 10+
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Native OCR channel — backed by Apple Vision (replaces Google ML Kit on iOS).
    OcrChannel.register(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

/// Performs on-device text recognition using Apple's Vision framework and
/// bridges it to Dart via a `MethodChannel`. Mirrors the Android ML Kit handler
/// so `OCRService.recognizeText` behaves identically on both platforms.
enum OcrChannel {
  static let channelName = "com.pranta.pinpoint/ocr"

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "recognizeText":
        guard
          let args = call.arguments as? [String: Any],
          let path = args["path"] as? String
        else {
          result(FlutterError(code: "bad_args", message: "Missing 'path' argument", details: nil))
          return
        }
        recognizeText(atPath: path, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func recognizeText(atPath path: String, result: @escaping FlutterResult) {
    // FlutterResult must be delivered on the platform (main) thread.
    func reply(_ value: Any?) {
      DispatchQueue.main.async { result(value) }
    }

    guard let image = UIImage(contentsOfFile: path), let cgImage = image.cgImage else {
      reply(FlutterError(code: "bad_image", message: "Could not load image at \(path)", details: nil))
      return
    }
    let orientation = cgOrientation(from: image.imageOrientation)

    DispatchQueue.global(qos: .userInitiated).async {
      let request = VNRecognizeTextRequest { request, error in
        if let error = error {
          reply(FlutterError(code: "ocr_failed", message: error.localizedDescription, details: nil))
          return
        }
        let observations = request.results as? [VNRecognizedTextObservation] ?? []
        let text = observations
          .compactMap { $0.topCandidates(1).first?.string }
          .joined(separator: "\n")
        reply(text)
      }
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true

      let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
      do {
        try handler.perform([request])
      } catch {
        reply(FlutterError(code: "ocr_failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  private static func cgOrientation(from ui: UIImage.Orientation) -> CGImagePropertyOrientation {
    switch ui {
    case .up: return .up
    case .upMirrored: return .upMirrored
    case .down: return .down
    case .downMirrored: return .downMirrored
    case .left: return .left
    case .leftMirrored: return .leftMirrored
    case .right: return .right
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
  }
}
