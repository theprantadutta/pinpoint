import 'dart:io';

import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:fleather/fleather.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database.dart';
import '../dtos/note_folder_dto.dart';
import '../service_locators/init_service_locators.dart';
import '../widgets/markdown_toolbar.dart';
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
  static const String _doneKey = 'dev_demo_seed_done_v2';

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

    final db = getIt<AppDatabase>();

    // Idempotent by title: re-running updates the body and colour of an
    // existing demo note instead of duplicating it.
    Future<void> text(String title, String body, List<NoteFolderDto> folders,
        {String? color, bool pinned = false}) async {
      final existing = await (db.select(db.textNotesV2)
            ..where((t) => t.title.equals(title) & t.isDeleted.equals(false)))
          .getSingleOrNull();
      final int id;
      if (existing != null) {
        id = existing.id;
        await TextNoteService.updateTextNote(
            noteId: id, content: body, isPinned: pinned);
      } else {
        id = await TextNoteService.createTextNote(
            title: title, content: body, folders: folders, isPinned: pinned);
      }
      if (color != null) await DriftNoteService.setNoteColor(id, 'text', color);
    }

    Future<bool> exists(String title) async =>
        await (db.select(db.todoListNotesV2)
                  ..where((t) => t.title.equals(title)))
                .getSingleOrNull() !=
            null ||
        await (db.select(db.voiceNotesV2)..where((t) => t.title.equals(title)))
                .getSingleOrNull() !=
            null ||
        await (db.select(db.reminderNotesV2)
                  ..where((t) => t.title.equals(title)))
                .getSingleOrNull() !=
            null;

    Future<void> todo(String title, List<String> open, List<String> done,
        List<NoteFolderDto> folders,
        {String? color}) async {
      if (await exists(title)) return;
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

    await text(
        'Essay outline',
        _rich([
          _h1('Intro'),
          _li('Hook with a question'),
          _li('Thesis in one line'),
          _h1('Body'),
          _li('Three arguments, one per paragraph'),
        ]),
        [homework],
        color: 'yellow');
    await todo('Calculus set', ['Problems 1–10', 'Review limits'],
        ['Read chapter 4'], [homework]);
    await text(
        'Match schedule',
        _rich([
          _p([_s('Saturday 10:00', bold: true), _s(' vs Rovers')]),
          _p([_s('Bring the blue kit')]),
        ]),
        [sports],
        color: 'pink');
    await text(
        'Q4 planning',
        _rich([
          _li('Ship the redesign'),
          _li('Hire a designer'),
          _li('Cut the backlog in half'),
        ]),
        [office]);
    await todo('Groceries', ['Buy Milk', 'Eggs, a dozen'],
        ['Bread', 'Coffee beans'], [random]);
    await text(
        'Spider-Man',
        _rich([
          _p([
            _s('Watch '),
            _s('Across the Spider-Verse', italic: true),
            _s(' again this weekend.'),
          ]),
        ]),
        [random],
        color: 'sky');
    await todo('Todos', ['Buy Milk'], ['Bread'], [random]);
    await text(
        'Important Address',
        _rich([
          _p([_s('221B Baker Street, London')])
        ]),
        [random],
        color: 'lavender',
        pinned: true);
    await text(
        'Random Note',
        _rich([
          _p([
            _s('Some letters are '),
            _s('bold', bold: true),
            _s(' and some are '),
            _s('italic', italic: true),
            _s(' and '),
            _s('some', highlight: true),
            _s(' are '),
            _s('both', bold: true, italic: true),
            _s('.'),
          ]),
          _h2('Key points'),
          _li("Progress is often invisible while you're making it."),
          _li('Most projects look like a mess until they work.'),
          _li('Keep shipping.'),
        ]),
        [random]);

    if (await exists('Leg day')) return;
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

  // ---- Fleather delta builders (the editor stores bodies as delta JSON) ----

  static String _rich(List<List<Map<String, dynamic>>> lines) =>
      jsonEncode([for (final l in lines) ...l]);

  static Map<String, dynamic> _op(String text, [Map<String, dynamic>? attrs]) =>
      {
        'insert': text,
        if (attrs != null && attrs.isNotEmpty) 'attributes': attrs
      };

  static Map<String, dynamic> _s(String text,
      {bool bold = false, bool italic = false, bool highlight = false}) {
    final a = <String, dynamic>{};
    if (bold) a.addAll(ParchmentAttribute.bold.toJson());
    if (italic) a.addAll(ParchmentAttribute.italic.toJson());
    if (highlight) {
      a.addAll(ParchmentAttribute.backgroundColor
          .withColor(MarkdownToolbar.highlightBackground)
          .toJson());
      a.addAll(ParchmentAttribute.foregroundColor
          .withColor(MarkdownToolbar.highlightForeground)
          .toJson());
    }
    return _op(text, a);
  }

  static List<Map<String, dynamic>> _p(List<Map<String, dynamic>> spans) =>
      [...spans, _op('\n')];

  static List<Map<String, dynamic>> _h1(String t) =>
      [_op(t), _op('\n', ParchmentAttribute.h1.toJson())];

  static List<Map<String, dynamic>> _h2(String t) =>
      [_op(t), _op('\n', ParchmentAttribute.h2.toJson())];

  static List<Map<String, dynamic>> _li(String t) =>
      [_op(t), _op('\n', ParchmentAttribute.ul.toJson())];

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
