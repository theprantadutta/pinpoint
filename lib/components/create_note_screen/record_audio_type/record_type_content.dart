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
    final kPrimaryColor = Theme.of(context).primaryColor;
    return SliverToBoxAdapter(
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.585,
        padding: EdgeInsets.all(20),
        margin: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: kPrimaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Record & Transcribe",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 30),
            GestureDetector(
              onTap: _isListening ? _stopListening : _startListening,
              child: AvatarGlow(
                animate: _isListening,
                glowColor: kPrimaryColor,
                duration: const Duration(milliseconds: 2000),
                repeat: true,
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  size: 80,
                  color: kPrimaryColor,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isListening ? "Listening..." : "Tap to Speak",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: _isListening ? kPrimaryColor : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _lastWords,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
