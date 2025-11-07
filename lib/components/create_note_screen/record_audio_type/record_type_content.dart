import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:avatar_glow/avatar_glow.dart';

class RecordTypeContent extends StatefulWidget {
  final Function(String transcribedText) onTranscribedText;

  const RecordTypeContent({
    super.key,
    required this.onTranscribedText,
  });

  @override
  State<RecordTypeContent> createState() => _RecordTypeContentState();
}

class _RecordTypeContentState extends State<RecordTypeContent> {
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {
      _isListening = true;
    });
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
    if (_lastWords.isNotEmpty) {
      widget.onTranscribedText(_lastWords);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Container(
          constraints: BoxConstraints(
            minHeight: MediaQuery.sizeOf(context).height * 0.5,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title
              Text(
                "Voice Recording",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Tap the microphone to start recording",
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),

              const SizedBox(height: 48),

              // Microphone Button
              GestureDetector(
                onTap: _isListening ? _stopListening : _startListening,
                child: AvatarGlow(
                  animate: _isListening,
                  glowColor: cs.primary,
                  duration: const Duration(milliseconds: 2000),
                  repeat: true,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cs.primary.withValues(alpha: isDark ? 0.3 : 0.2),
                          cs.primary.withValues(alpha: isDark ? 0.2 : 0.15),
                        ],
                      ),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      size: 56,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Status Text
              Text(
                _isListening ? "Listening..." : "Tap to speak",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _isListening
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.6),
                ),
              ),

              const SizedBox(height: 40),

              // Transcribed Text
              if (_lastWords.isNotEmpty)
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.25,
                  ),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
                        : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outline.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _lastWords,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.graphic_eq_rounded,
                        size: 48,
                        color: cs.onSurface.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your transcribed text will appear here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
