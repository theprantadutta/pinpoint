import 'package:speech_to_text/speech_to_text.dart';
import 'package:pinpoint/services/logger_service.dart';

class TranscriptionService {
  static final SpeechToText _speechToText = SpeechToText();

  /// Transcribe audio file to text
  ///
  /// NOTE: Audio file transcription is not yet implemented.
  /// This requires integration with a cloud speech-to-text API such as:
  /// - Google Cloud Speech-to-Text
  /// - OpenAI Whisper API
  /// - AWS Transcribe
  ///
  /// The `speech_to_text` package only handles live microphone input.
  /// For file transcription, you would need to:
  /// 1. Read the audio file into bytes
  /// 2. Send bytes to a speech-to-text API
  /// 3. Parse the API response
  ///
  /// Returns null to indicate transcription is not available.
  static Future<String?> transcribeAudio(String audioPath) async {
    log.w('Audio file transcription is not implemented. Path: $audioPath');
    // Return null to indicate feature is not available
    // Callers should handle null gracefully
    return null;
  }

  static Future<bool> initialize() async {
    return await _speechToText.initialize(
        onStatus: (status) => log.i('Speech recognition status: $status'),
        onError: (error) => log.e('Speech recognition error: $error'));
  }

  static Future<bool> isAvailable() async {
    return _speechToText.isAvailable;
  }

  static void dispose() {
    _speechToText.stop();
  }
}
