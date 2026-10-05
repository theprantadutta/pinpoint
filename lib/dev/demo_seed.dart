import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dtos/note_folder_dto.dart';
import '../services/drift_note_folder_service.dart';
import '../services/drift_note_service.dart';
import '../services/reminder_note_service.dart';
import '../services/text_note_service.dart';
import '../services/todo_list_note_service.dart';
import '../services/voice_note_service.dart';

/// Demo content for design QA and store screenshots.
///
/// Compiled in only for debug builds started with
/// `--dart-define=PINPOINT_SEED_DEMO=true`, and runs once per install. It
/// writes through the normal services, so the notes are encrypted and synced
/// like any other — seed a test account, not a real one.
class DemoSeed {
  DemoSeed._();

  static const bool enabled =
      kDebugMode && bool.fromEnvironment('PINPOINT_SEED_DEMO');
  static const String _doneKey = 'dev_demo_seed_done_v1';

  static Future<void> runOnceIfEnabled() async {
    if (!enabled) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_doneKey) ?? false) return;
    await prefs.setBool(_doneKey, true);
    try {
      await _seed();
      debugPrint('🌱 [DemoSeed] Demo content created');
    } catch (e, st) {
      debugPrint('🌱 [DemoSeed] Failed: $e\n$st');
    }
  }

  static Future<NoteFolderDto> _folder(String title) async {
    final existing = await DriftNoteFolderService.watchFolders().first;
    for (final f in existing) {
      if (f.noteFolderTitle.toLowerCase() == title.toLowerCase()) {
        return NoteFolderDto(id: f.noteFolderId, title: f.noteFolderTitle);
      }
    }
    return DriftNoteFolderService.insertNoteFolder(title);
  }

  static Future<void> _seed() async {
    final random = await _folder('Random');
    final homework = await _folder('HomeWork');
    final workout = await _folder('Workout');
    final office = await _folder('Office');
    final sports = await _folder('Sports');

    Future<void> text(String title, String body, List<NoteFolderDto> folders,
        {String? color, bool pinned = false}) async {
      final id = await TextNoteService.createTextNote(
          title: title, content: body, folders: folders, isPinned: pinned);
      if (color != null) await DriftNoteService.setNoteColor(id, 'text', color);
    }

    Future<void> todo(String title, List<String> open, List<String> done,
        List<NoteFolderDto> folders,
        {String? color}) async {
      final id = await TodoListNoteService.createTodoListNote(
          title: title, folders: folders, initialItems: [...open, ...done]);
      final items = await TodoListNoteService.watchTodoItems(id).first;
      for (final item in items) {
        if (done.contains(item.content)) {
          await TodoListNoteService.toggleTodoItemCompletion(item.id);
        }
      }
      if (color != null) await DriftNoteService.setNoteColor(id, 'todo', color);
    }

    await text('Essay outline',
        '# Intro\n- Hook with a question\n- Thesis in one line\n# Body\n- Three arguments',
        [homework],
        color: 'yellow');
    await todo('Calculus set', ['Problems 1–10', 'Review limits'],
        ['Read chapter 4'], [homework]);
    await text('Match schedule', 'Saturday 10:00 vs Rovers\nBring the blue kit',
        [sports],
        color: 'pink');
    await text('Q4 planning',
        'Ship the redesign\nHire a designer\nCut the backlog in half', [office]);
    await todo('Groceries', ['Buy Milk', 'Eggs, a dozen'],
        ['Bread', 'Coffee beans'], [random]);
    await text('Spider-Man', 'Watch Across the Spider-Verse again this weekend.',
        [random],
        color: 'sky');
    await todo('Todos', ['Buy Milk'], ['Bread'], [random]);
    await text('Important Address', '221B Baker Street, London', [random],
        color: 'lavender', pinned: true);
    await text(
        'Random Note',
        '- Progress is often invisible\n- Most projects look like a mess\n- Keep shipping',
        [random]);

    final audio = await _silentWav();
    await VoiceNoteService.createVoiceNote(
      title: 'Leg day',
      audioFilePath: audio,
      folders: [workout],
      durationSeconds: 42,
    );

    var at = DateTime.now();
    at = DateTime(at.year, at.month, at.day, 18);
    if (at.isBefore(DateTime.now())) at = at.add(const Duration(days: 1));
    await ReminderNoteService.createReminderNote(
      title: 'Stand-up notes',
      notificationTitle: 'Stand-up notes',
      notificationContent: 'Share the redesign progress',
      reminderTime: at,
      folders: [office],
    );
  }

  /// One second of 8 kHz mono silence, so the voice note has a real file.
  static Future<String> _silentWav() async {
    const rate = 8000;
    final data = Uint8List(rate);
    final header = ByteData(44)
      ..setUint32(0, 0x52494646) // RIFF
      ..setUint32(4, 36 + data.length, Endian.little)
      ..setUint32(8, 0x57415645) // WAVE
      ..setUint32(12, 0x666d7420) // fmt
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, 1, Endian.little)
      ..setUint32(24, rate, Endian.little)
      ..setUint32(28, rate, Endian.little)
      ..setUint16(32, 1, Endian.little)
      ..setUint16(34, 8, Endian.little)
      ..setUint32(36, 0x64617461) // data
      ..setUint32(40, data.length, Endian.little);
    for (var i = 0; i < data.length; i++) {
      data[i] = 128;
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/demo_leg_day.wav');
    await file.writeAsBytes([...header.buffer.asUint8List(), ...data]);
    return file.path;
  }
}
