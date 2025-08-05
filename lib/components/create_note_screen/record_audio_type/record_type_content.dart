import 'dart:io';
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:pinpoint/services/transcription_service.dart';

class RecordTypeContent extends StatefulWidget {
  final String? audioPath;
  final Function(String? audioPath) onAudioPathChanged;
  final int? audioDuration;
  final Function(int audioDuration) onAudioDurationChanged;
  final Function(String transcribedText) onTranscribedText;

  const RecordTypeContent({
    super.key,
    required this.audioPath,
    required this.onAudioPathChanged,
    required this.audioDuration,
    required this.onAudioDurationChanged,
    required this.onTranscribedText,
  });

  @override
  State<RecordTypeContent> createState() => _RecordTypeContentState();
}

class _RecordTypeContentState extends State<RecordTypeContent> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _onCompleteSub;
  bool _isRecording = false;
  bool _isPlaying = false;

  Future<void> _startRecording() async {
    if (!mounted) return;
    if (await _recorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      final currentAudioPath = '${dir.path}/my_audio.m4a';

      await _recorder.start(RecordConfig(), path: currentAudioPath);

      if (!mounted) return;
      setState(() {
        _isRecording = true;
      });
      widget.onAudioPathChanged(currentAudioPath);
    }
  }

  Future<void> _stopRecording() async {
    await _recorder.stop();
    if (!mounted) return;
    setState(() => _isRecording = false);

    if (widget.audioPath != null) {
      final bool? doTranscribe = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Transcribe Audio?'),
          content:
              const Text('Do you want to transcribe this audio recording?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );

      if (doTranscribe == true) {
        final String transcribedText =
            await TranscriptionService.transcribeAudio(widget.audioPath!);
        if (!mounted) return;
        if (transcribedText.isNotEmpty) {
          widget.onTranscribedText(transcribedText);
        }
      }
    }
  }

  Future<void> _playAudio() async {
    if (widget.audioPath != null && File(widget.audioPath!).existsSync()) {
      await _player.play(DeviceFileSource(widget.audioPath!));
      if (!mounted) return;
      setState(() => _isPlaying = true);

      _onCompleteSub?.cancel();
      _onCompleteSub = _player.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() => _isPlaying = false);
      });
    }
  }

  @override
  void dispose() {
    try {
      _onCompleteSub?.cancel();
    } catch (_) {}
    try {
      _recorder.dispose();
    } catch (_) {}
    try {
      _player.dispose();
    } catch (_) {}
    super.dispose();
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
              "Record Audio Note",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 30),
            GestureDetector(
              onTap: _isRecording ? _stopRecording : _startRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 150,
                width: 150,
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: AvatarGlow(
                  animate: _isRecording,
                  duration: Duration(milliseconds: 1000),
                  glowColor: _isRecording ? kPrimaryColor : Colors.white,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? kPrimaryColor.withValues(alpha: 0.2)
                            : kPrimaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic_outlined,
                        color: _isRecording ? Colors.white : kPrimaryColor,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            AnimatedOpacity(
              opacity: _isRecording ? 1.0 : 0.5,
              duration: const Duration(milliseconds: 300),
              child: Text(
                _isRecording ? "Recording..." : "Press to Record",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: _isRecording ? kPrimaryColor : Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 30),
            if (widget.audioPath != null &&
                File(widget.audioPath!).existsSync())
              GestureDetector(
                onTap: _playAudio,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: BoxDecoration(
                    color: _isPlaying
                        ? kPrimaryColor
                        : kPrimaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_arrow,
                        color: _isPlaying ? Colors.white : Colors.black,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isPlaying ? "Playing..." : "Play Recording",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _isPlaying ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
