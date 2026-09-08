import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/database/database.dart';
import 'package:sqlite3/sqlite3.dart';

/// Upgrade test for schema v11 — the migration every existing install runs.
///
/// v11 does two things that cannot be verified on a fresh database: it rebuilds
/// the three tables whose foreign keys declared no `ON DELETE` rule, and it
/// deletes the orphan rows that accumulated over every release that ran with
/// foreign keys unenforced. Switching enforcement on over a database still
/// holding those orphans is what would turn a latent bug into runtime
/// failures, so this exercises the real [AppDatabase] migration against a real
/// v10-shaped file.
///
/// The v10 shape is derived from the shipping schema rather than hand-written:
/// the only difference is the missing `ON DELETE CASCADE`, so stripping that
/// clause from the live DDL reproduces exactly what is on devices today.
void main() {
  late Directory tempDir;
  late File dbFile;

  /// Tables whose foreign keys v11 repairs.
  const repairedTables = [
    'note_attachments',
    'note_todo_items',
    'todo_items_v2',
  ];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pinpoint_migration_test');
    dbFile = File('${tempDir.path}/pinpoint.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Creates the current schema on disk, then rewinds it to v10.
  Future<void> createV10Database() async {
    final current = AppDatabase.forTesting(NativeDatabase(dbFile));
    // Force the schema to be created.
    await current.customSelect('SELECT 1').getSingle();
    await current.close();

    final raw = sqlite3.open(dbFile.path);
    raw.execute('PRAGMA foreign_keys = OFF');

    for (final table in repairedTables) {
      final ddl = raw.select(
        'SELECT sql FROM sqlite_master WHERE type = ? AND name = ?',
        ['table', table],
      ).single['sql'] as String;

      // The pre-v11 definition, byte for byte: same columns, no action rules.
      final legacyDdl = ddl
          .replaceAll(' ON UPDATE CASCADE', '')
          .replaceAll(' ON DELETE CASCADE', '');
      expect(legacyDdl, isNot(ddl),
          reason: '$table should have had a cascade to strip');

      raw
        ..execute('ALTER TABLE "$table" RENAME TO "${table}_pre_v11"')
        ..execute(legacyDdl)
        ..execute('INSERT INTO "$table" SELECT * FROM "${table}_pre_v11"')
        ..execute('DROP TABLE "${table}_pre_v11"');
    }

    raw
      ..execute('PRAGMA user_version = 10')
      ..close();
  }

  /// Fills the v10 database with a healthy note and the orphans that only an
  /// unenforced schema could have produced.
  void seedV10Data() {
    final raw = sqlite3.open(dbFile.path);
    raw.execute('PRAGMA foreign_keys = OFF');

    raw.execute(
      'INSERT INTO notes (id, uuid, note_type, created_at, updated_at) '
      'VALUES (1, ?, ?, 0, 0)',
      ['note-1', 'text'],
    );
    raw.execute(
      'INSERT INTO todo_list_notes_v2 (id, uuid, created_at, updated_at) '
      'VALUES (1, ?, 0, 0)',
      ['list-1'],
    );

    // Rows that must survive the migration.
    raw.execute(
      'INSERT INTO note_attachments (id, note_id, attachment_name, attachment_path) '
      'VALUES (1, 1, ?, ?)',
      ['keep.png', '/tmp/keep.png'],
    );
    raw.execute(
      'INSERT INTO note_todo_items (id, uuid, note_id, note_uuid, todo_title) '
      'VALUES (1, ?, 1, ?, ?)',
      ['item-keep', 'note-1', 'buy milk'],
    );
    raw.execute(
      'INSERT INTO todo_items_v2 '
      '(id, uuid, todo_list_note_id, todo_list_note_uuid, content, created_at, updated_at) '
      'VALUES (1, ?, 1, ?, ?, 0, 0)',
      ['v2-keep', 'list-1', 'call the bank'],
    );

    // Leftovers from notes deleted while nothing enforced the cascades.
    raw.execute(
      'INSERT INTO note_attachments (id, note_id, attachment_name, attachment_path) '
      'VALUES (2, 404, ?, ?)',
      ['orphan.png', '/tmp/orphan.png'],
    );
    // Valid note_id, dangling note_uuid — only reachable via the column that
    // had no delete rule at all.
    raw.execute(
      'INSERT INTO note_todo_items (id, uuid, note_id, note_uuid, todo_title) '
      'VALUES (2, ?, 1, ?, ?)',
      ['item-orphan', 'note-that-was-deleted', 'ghost task'],
    );
    raw.execute(
      'INSERT INTO todo_items_v2 '
      '(id, uuid, todo_list_note_id, todo_list_note_uuid, content, created_at, updated_at) '
      'VALUES (2, ?, 1, ?, ?, 0, 0)',
      ['v2-orphan', 'list-that-was-deleted', 'ghost item'],
    );

    raw.close();
  }

  Future<AppDatabase> openAndMigrate() async {
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    // Any query forces drift to open the database and run the migration.
    await db.customSelect('SELECT 1').getSingle();
    return db;
  }

  test('a v10 database has the defect this migration repairs', () async {
    await createV10Database();

    final raw = sqlite3.open(dbFile.path);
    final version = raw.select('PRAGMA user_version').single.values.first;
    final ddl = raw.select(
      'SELECT sql FROM sqlite_master WHERE name = ?',
      ['note_attachments'],
    ).single['sql'] as String;
    raw.close();

    // Guards the setup itself: without this the migration assertions could
    // pass against a database that was never actually v10.
    expect(version, 10);
    expect(ddl, isNot(contains('ON DELETE CASCADE')));
  });

  test('upgrading to v11 gives every repaired table a cascade', () async {
    await createV10Database();
    seedV10Data();

    final db = await openAndMigrate();
    addTearDown(db.close);

    for (final table in repairedTables) {
      final keys =
          await db.customSelect('PRAGMA foreign_key_list("$table")').get();
      expect(keys, isNotEmpty, reason: '$table lost its foreign keys');
      for (final key in keys) {
        expect(key.read<String>('on_delete'), 'CASCADE',
            reason: '$table.${key.read<String>('from')} did not get a cascade');
      }
    }
  });

  test('upgrading to v11 keeps real rows and drops orphans', () async {
    await createV10Database();
    seedV10Data();

    final db = await openAndMigrate();
    addTearDown(db.close);

    Future<List<String>> idsIn(String table, String column) async {
      final rows =
          await db.customSelect('SELECT "$column" AS v FROM "$table"').get();
      return [for (final row in rows) row.read<String>('v')];
    }

    expect(await idsIn('note_attachments', 'attachment_name'), ['keep.png']);
    expect(await idsIn('note_todo_items', 'uuid'), ['item-keep']);
    expect(await idsIn('todo_items_v2', 'uuid'), ['v2-keep']);
  });

  test('the migrated database is consistent and enforcing', () async {
    await createV10Database();
    seedV10Data();

    final db = await openAndMigrate();
    addTearDown(db.close);

    final violations = await db.customSelect('PRAGMA foreign_key_check').get();
    expect(violations, isEmpty);

    final enforced = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(enforced.data.values.first, 1);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, 11);
  });

  test('cascades work on a migrated database, not just a fresh one', () async {
    await createV10Database();
    seedV10Data();

    final db = await openAndMigrate();
    addTearDown(db.close);

    await db.customStatement('DELETE FROM notes WHERE id = 1');

    Future<int> countOf(String table) async {
      final row = await db
          .customSelect('SELECT COUNT(*) AS c FROM "$table"')
          .getSingle();
      return row.read<int>('c');
    }

    expect(await countOf('note_attachments'), 0);
    expect(await countOf('note_todo_items'), 0);
  });

  test('reopening an already-migrated database is a no-op', () async {
    await createV10Database();
    seedV10Data();

    final first = await openAndMigrate();
    await first.close();

    // The upgrade path must be idempotent across restarts — this is the open
    // that every subsequent app launch performs.
    final second = await openAndMigrate();
    addTearDown(second.close);

    final rows = await second
        .customSelect('SELECT COUNT(*) AS c FROM note_todo_items')
        .getSingle();
    expect(rows.read<int>('c'), 1);

    final violations =
        await second.customSelect('PRAGMA foreign_key_check').get();
    expect(violations, isEmpty);
  });
}
