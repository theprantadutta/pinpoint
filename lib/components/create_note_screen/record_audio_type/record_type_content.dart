import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordTypeContent extends StatefulWidget {
  const RecordTypeContent({super.key});

  @override
  State<RecordTypeContent> createState() => _RecordTypeContentState();
}

class _RecordTypeContentState extends State<RecordTypeContent> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _audioPath;

  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      _audioPath = '${dir.path}/my_audio.m4a';

      await _recorder.start(RecordConfig(), path: _audioPath!);
      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopRecording() async {
    await _recorder.stop();
    setState(() => _isRecording = false);
  }

  Future<void> _playAudio() async {
    if (_audioPath != null && File(_audioPath!).existsSync()) {
      await _player.play(DeviceFileSource(_audioPath!));
      setState(() => _isPlaying = true);

      _player.onPlayerComplete.listen((_) {
        setState(() => _isPlaying = false);
      });
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    return SliverToBoxAdapter(
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.59,
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
            if (_audioPath != null && File(_audioPath!).existsSync())
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
