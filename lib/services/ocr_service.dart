import 'package:flutter/services.dart';

/// On-device OCR (image → text).
///
/// Backed by native platform OCR engines through a [MethodChannel]:
///   * iOS     — Apple Vision (`VNRecognizeTextRequest`)
///   * Android — Google ML Kit text recognition
///
/// This replaces the `google_mlkit_text_recognition` Flutter plugin, whose iOS
/// binaries ship no arm64-simulator slice and therefore cannot build/run on
/// Apple-Silicon iOS 26+ simulators. The native handlers live in
/// `ios/Runner/AppDelegate.swift` and
/// `android/app/src/main/kotlin/com/pranta/pinpoint/MainActivity.kt`.
class OCRService {
  static const MethodChannel _channel =
      MethodChannel('com.pranta.pinpoint/ocr');

  /// Recognizes text in the image at [imagePath] and returns it as a single
  /// string (empty when nothing is detected).
  static Future<String> recognizeText(String imagePath) async {
    final String? text = await _channel.invokeMethod<String>(
      'recognizeText',
      <String, dynamic>{'path': imagePath},
    );
    return text ?? '';
  }

  /// Retained for API compatibility. The native OCR engines are stateless, so
  /// there is nothing to tear down.
  static void dispose() {}
}
