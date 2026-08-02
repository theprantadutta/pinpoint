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
        recognizeText(atPath: path, languageTag: args["languageTag"] as? String, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func recognizeText(
    atPath path: String,
    languageTag: String?,
    result: @escaping FlutterResult
  ) {
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
      let languages = recognitionLanguages(for: request, preferring: languageTag)
      if !languages.isEmpty {
        request.recognitionLanguages = languages
      }

      let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
      do {
        try handler.perform([request])
      } catch {
        reply(FlutterError(code: "ocr_failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  /// The languages Vision should recognize, ranked, for a user reading the app
  /// in `tag` (an app locale code like `es` or `pt`).
  ///
  /// Vision defaults to `en-US` alone. That is not merely narrow: with
  /// `usesLanguageCorrection` on, scanning a Spanish or French note makes Vision
  /// correct its accented words *toward English*, so the localized app returned
  /// worse text than an unlocalized one would. Android has no equivalent bug —
  /// ML Kit's `DEFAULT_OPTIONS` recognizer covers the whole Latin script in one
  /// model — which is why this only ever needed fixing here.
  ///
  /// English is kept as a second choice because scanned material (UI, product
  /// packaging, code) is so often English regardless of the reader's language.
  ///
  /// The result is always intersected with what this OS build actually ships a
  /// model for: `recognitionLanguages` throws on an unsupported tag, and the
  /// supported set both grows across iOS releases and varies by
  /// `recognitionLevel`. So Thai and Arabic switch themselves on wherever
  /// Apple supports them, while Bengali and Persian — which Vision has no model
  /// for — fall out here and degrade to English rather than failing the scan.
  private static func recognitionLanguages(
    for request: VNRecognizeTextRequest,
    preferring tag: String?
  ) -> [String] {
    guard let supported = try? request.supportedRecognitionLanguages(),
          !supported.isEmpty
    else { return [] }

    var picked: [String] = []
    for language in [tag, "en"].compactMap({ $0 }) {
      // Match on the language subtag: the app stores "pt", Vision offers "pt-BR".
      guard
        let match = supported.first(where: { $0 == language || $0.hasPrefix("\(language)-") }),
        !picked.contains(match)
      else { continue }
      picked.append(match)
    }
    return picked
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
