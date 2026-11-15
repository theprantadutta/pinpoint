import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/drift_note_service.dart';

/// Search on the All notes screen (watchNotesWithDetailsV2). It used to match a
/// checklist by its title only, so "milk" missed a list with "Buy Milk" in it,
/// and it matched text notes against the raw rich-text JSON, so a word like
/// "insert" found every note.
void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 11, 15);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (getIt.isRegistered<AppDatabase>()) getIt.unregister<AppDatabase>();
    getIt.registerSingleton<AppDatabase>(db);

    await db.into(db.textNotesV2).insert(TextNotesV2Companion.insert(
          uuid: 'text-1',
          title: const Value('Weekend in Lisbon'),
          content: jsonEncode([
            {'insert': 'Tram 28 up to the castle\n'},
          ]),
          createdAt: now,
          updatedAt: now,
        ));
    final listId = await db.into(db.todoListNotesV2).insert(TodoListNotesV2Companion.insert(
          uuid: 'list-1',
          title: const Value('Groceries'),
          createdAt: now,
          updatedAt: now,
        ));
    await db.into(db.todoItemsV2).insert(TodoItemsV2Companion.insert(
          uuid: 'item-1',
          todoListNoteId: listId,
          todoListNoteUuid: 'list-1',
          content: 'Buy Milk',
          createdAt: now,
          updatedAt: now,
        ));
  });

  tearDown(() async {
    getIt.unregister<AppDatabase>();
    await db.close();
  });

  Future<List<String>> search(String query) async {
    final notes = await DriftNoteService.watchNotesWithDetailsV2(searchQuery: query).first;
    return notes.map((n) => n.note.noteTitle ?? "").toList();
  }

  test('a checklist is found by one of its items', () async {
    expect(await search('milk'), ['Groceries']);
  });

  test('a text note is found by its words, not its storage format', () async {
    expect(await search('tram'), ['Weekend in Lisbon']);
    expect(await search('insert'), isEmpty);
  });

  test('titles still match', () async {
    expect(await search('grocer'), ['Groceries']);
    expect(await search('lisbon'), ['Weekend in Lisbon']);
  });
}
