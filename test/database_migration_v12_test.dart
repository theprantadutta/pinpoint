import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/design_system/colors.dart';
import 'package:pinpoint/models/folder_summary.dart';
import 'package:pinpoint/services/drift_note_folder_service.dart';
import 'package:pinpoint/util/folder_palette.dart';
import 'package:sqlite3/sqlite3.dart';

/// Schema v12 adds the Sketchbook folder colour and manual order. Both are
/// nullable additions, so the migration must keep every existing folder and
/// leave the new columns null — the colour then resolves at display time.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pinpoint_migration_v12');
    dbFile = File('${tempDir.path}/pinpoint.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Creates the current schema, then rewinds note_folders to v11.
  Future<void> createV11Database() async {
    final current = AppDatabase.forTesting(NativeDatabase(dbFile));
    await current.customSelect('SELECT 1').getSingle();
    await current.close();

    final raw = sqlite3.open(dbFile.path);
    raw
      ..execute('ALTER TABLE note_folders DROP COLUMN color')
      ..execute('ALTER TABLE note_folders DROP COLUMN sort_order')
      ..execute(
          "INSERT INTO note_folders (uuid, note_folder_title, created_at, updated_at) "
          "VALUES ('u-1', 'Random', 1700000000, 1700000000), "
          "('u-2', 'Work', 1700000100, 1700000100)")
      ..execute('PRAGMA user_version = 11')
      ..close();
  }

  test('v11 → v12 adds nullable colour and order, keeping folders', () async {
    await createV11Database();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    final folders = await db.select(db.noteFolders).get();
    await db.close();

    expect(folders.map((f) => f.noteFolderTitle), ['Random', 'Work']);
    expect(folders.every((f) => f.color == null && f.sortOrder == null),
        isTrue);

    final raw = sqlite3.open(dbFile.path);
    final version = raw.select('PRAGMA user_version').single.values.first;
    raw.close();
    expect(version, 12);
  });

  group('FolderPalette', () {
    NoteFolder folder(int id, String uuid, int createdSeconds,
            {String? color, int? order}) =>
        NoteFolder(
          noteFolderId: id,
          uuid: uuid,
          noteFolderTitle: 'F$id',
          createdAt:
              DateTime.fromMillisecondsSinceEpoch(createdSeconds * 1000),
          updatedAt:
              DateTime.fromMillisecondsSinceEpoch(createdSeconds * 1000),
          color: color,
          sortOrder: order,
        );

    test('stored colours win; the rest go round-robin by creation', () {
      // Local ids differ from creation order on purpose: ids are per device.
      final colors = FolderPalette.resolve([
        folder(9, 'b', 200),
        folder(3, 'a', 100),
        folder(5, 'c', 300, color: 'pink'),
      ]);
      expect(colors[3], SketchPastels.yellow);
      expect(colors[9], SketchPastels.lavender);
      expect(colors[5], SketchPastels.pink);
    });

    test('new folders continue the round-robin', () {
      expect(FolderPalette.nameForNewFolder(0), 'yellow');
      expect(FolderPalette.nameForNewFolder(4), 'pink');
      expect(FolderPalette.nameForNewFolder(5), 'yellow');
    });

    test('manual order first, then creation order', () {
      final ordered = FolderPalette.ordered([
        folder(1, 'a', 100),
        folder(2, 'b', 200, order: 1),
        folder(3, 'c', 300, order: 0),
      ]);
      expect(ordered.map((f) => f.noteFolderId), [3, 2, 1]);
    });

    test('uncoloured notes take their type pastel', () {
      expect(FolderPalette.forNote(type: 'todo'), SketchPastels.mint);
      expect(FolderPalette.forNote(type: 'voice'), SketchPastels.sky);
      expect(FolderPalette.forNote(colorName: 'dusk', type: 'todo'),
          SketchPastels.lavender);
    });

    test('summaries count notes and keep the newest four', () {
      final summaries = DriftNoteFolderService.buildSummaries(
        [folder(1, 'a', 100), folder(2, 'b', 200)],
        [
          for (var i = 0; i < 6; i++)
            FolderNoteRow(
                folderId: 1,
                noteId: i,
                type: i == 0 ? 'voice' : 'text',
                title: 'Note $i\nsecond line'),
        ],
      );
      expect(summaries.first.noteCount, 6);
      expect(summaries.first.voiceCount, 1);
      expect(summaries.first.recent.length, FolderSummary.previewLimit);
      expect(summaries.first.recent.first.title, 'Note 0');
      expect(summaries.last.noteCount, 0);
    });
  });
}
