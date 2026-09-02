import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/dtos/note_folder_dto.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/drift_note_folder_service.dart';

/// Foreign-key tests for the real production schema.
///
/// Every `references(..., onDelete: KeyAction.cascade)` in `lib/entities/` was
/// decorative until schema v11: SQLite defaults `PRAGMA foreign_keys` to OFF on
/// each new connection and nothing ever turned it on, so no cascade had ever
/// run on any device. Three columns did not even declare a rule
/// (`note_attachments.note_id`, `note_todo_items.note_uuid`,
/// `todo_items_v2.todo_list_note_uuid`), which would have made deleting a note
/// fail outright the moment enforcement was switched on.
///
/// These run [AppDatabase] itself against an in-memory database, so the
/// schema, the migration strategy and the `beforeOpen` hook under test are the
/// exact ones that ship — not a stand-in.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> countOf(String table) async {
    final row =
        await db.customSelect('SELECT COUNT(*) AS c FROM "$table"').getSingle();
    return row.read<int>('c');
  }

  final now = DateTime.utc(2026, 9, 2);

  /// Inserts a base-table note plus one child row in every table that hangs off
  /// it, and returns the note's local id.
  Future<int> insertNoteWithChildren({String uuid = 'note-1'}) async {
    final noteId = await db.into(db.notes).insert(
          NotesCompanion.insert(
            uuid: uuid,
            noteType: 'text',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final folderId = await db.into(db.noteFolders).insert(
          NoteFoldersCompanion.insert(
            uuid: 'folder-for-$uuid',
            noteFolderTitle: 'Folder for $uuid',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db.into(db.textNotes).insert(TextNotesCompanion.insert(
        noteId: Value(noteId), content: const Value('body text')));
    await db.into(db.audioNotes).insert(AudioNotesCompanion.insert(
        noteId: Value(noteId), audioFilePath: '/tmp/a.m4a'));
    await db
        .into(db.todoNotes)
        .insert(TodoNotesCompanion.insert(noteId: Value(noteId)));
    await db.into(db.reminderNotes).insert(ReminderNotesCompanion.insert(
        noteId: Value(noteId), reminderTime: now));
    await db.into(db.noteTodoItems).insert(
          NoteTodoItemsCompanion.insert(
            uuid: 'item-for-$uuid',
            noteId: noteId,
            noteUuid: uuid,
            todoTitle: 'buy milk',
          ),
        );
    await db.into(db.noteAttachments).insert(
          NoteAttachmentsCompanion.insert(
            noteId: noteId,
            attachmentName: 'receipt.png',
            attachmentPath: '/tmp/receipt.png',
          ),
        );
    await db.into(db.noteFolderRelations).insert(
          NoteFolderRelationsCompanion.insert(
            noteId: noteId,
            noteFolderId: folderId,
          ),
        );

    return noteId;
  }

  test('foreign keys are enforced on an opened database', () async {
    // Proves MigrationStrategy.beforeOpen actually ran the pragma. Every
    // cascade assertion below is vacuous without this.
    final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(row.data.values.first, 1);
  });

  test('every foreign key in the schema cascades on delete', () async {
    // The regression guard for the defect itself: a new `references()` written
    // without `onDelete:` fails here rather than silently leaving orphans or,
    // now that enforcement is on, blocking note deletion at runtime.
    final withoutCascade = <String>[];
    var totalKeys = 0;

    for (final table in db.allTables) {
      final keys = await db
          .customSelect('PRAGMA foreign_key_list("${table.actualTableName}")')
          .get();
      for (final key in keys) {
        totalKeys++;
        if (key.read<String>('on_delete') != 'CASCADE') {
          withoutCascade.add(
              '${table.actualTableName}.${key.read<String>('from')} -> '
              '${key.read<String>('table')} (${key.read<String>('on_delete')})');
        }
      }
    }

    expect(totalKeys, greaterThan(0), reason: 'no foreign keys were inspected');
    expect(withoutCascade, isEmpty);
  });

  test('deleting a note removes every row that hangs off it', () async {
    final noteId = await insertNoteWithChildren();

    await (db.delete(db.notes)..where((n) => n.id.equals(noteId))).go();

    expect(await countOf('notes'), 0);
    expect(await countOf('text_notes'), 0);
    expect(await countOf('audio_notes'), 0);
    expect(await countOf('todo_notes'), 0);
    expect(await countOf('reminder_notes'), 0);
    // The two columns that declared no ON DELETE rule before v11.
    expect(await countOf('note_todo_items'), 0);
    expect(await countOf('note_attachments'), 0);
    expect(await countOf('note_folder_relations'), 0);
    // The folder is not a child of the note and must survive.
    expect(await countOf('note_folders'), 1);
  });

  test('deleting a todo list note removes its items', () async {
    final listId = await db.into(db.todoListNotesV2).insert(
          TodoListNotesV2Companion.insert(
            uuid: 'list-1',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.todoItemsV2).insert(
          TodoItemsV2Companion.insert(
            uuid: 'v2-item-1',
            todoListNoteId: listId,
            todoListNoteUuid: 'list-1',
            content: 'call the bank',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await (db.delete(db.todoListNotesV2)..where((n) => n.id.equals(listId)))
        .go();

    expect(await countOf('todo_items_v2'), 0);
  });

  test('deleting a folder removes its note relations but not the notes',
      () async {
    final folderId = await db.into(db.noteFolders).insert(
          NoteFoldersCompanion.insert(
            uuid: 'folder-1',
            noteFolderTitle: 'Work',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final textId = await db.into(db.textNotesV2).insert(
          TextNotesV2Companion.insert(
            uuid: 'text-1',
            content: 'hello',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.textNoteFolderRelationsV2).insert(
          TextNoteFolderRelationsV2Companion.insert(
            textNoteId: textId,
            folderId: folderId,
          ),
        );

    await (db.delete(db.noteFolders)
          ..where((f) => f.noteFolderId.equals(folderId)))
        .go();

    expect(await countOf('text_note_folder_relations_v2'), 0);
    expect(await countOf('text_notes_v2'), 1);
  });

  test('renaming a note uuid carries through to its checklist items', () async {
    // note_todo_items.note_uuid and todo_items_v2.todo_list_note_uuid point at
    // a natural key that sync can rewrite. Without ON UPDATE CASCADE,
    // enforcement would turn that rewrite into a constraint failure instead of
    // updating the children.
    final noteId = await insertNoteWithChildren();

    await (db.update(db.notes)..where((n) => n.id.equals(noteId)))
        .write(const NotesCompanion(uuid: Value('note-renamed-by-sync')));

    final item = await db.select(db.noteTodoItems).getSingle();
    expect(item.noteUuid, 'note-renamed-by-sync');
    expect(await countOf('note_todo_items'), 1);
  });

  test('a child row pointing at a missing parent is rejected', () async {
    await expectLater(
      db.into(db.noteAttachments).insert(
            NoteAttachmentsCompanion.insert(
              noteId: 9999,
              attachmentName: 'ghost.png',
              attachmentPath: '/tmp/ghost.png',
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('linking a note to a deleted folder is dropped, not fatal', () async {
    // Folder pickers hold a list read earlier in the session. With foreign
    // keys enforced, a folder deleted in the meantime would fail the whole
    // note save; DriftNoteFolderService.existingFolders drops it instead.
    getIt.registerSingleton<AppDatabase>(db);
    addTearDown(() => getIt.unregister<AppDatabase>());

    final liveId = await db.into(db.noteFolders).insert(
          NoteFoldersCompanion.insert(
            uuid: 'folder-live',
            noteFolderTitle: 'Still here',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final surviving = await DriftNoteFolderService.existingFolders([
      NoteFolderDto(id: liveId, title: 'Still here'),
      NoteFolderDto(id: 4040, title: 'Deleted while the picker was open'),
    ]);

    expect([for (final f in surviving) f.id], [liveId]);
  });

  test('a populated database reports no foreign key violations', () async {
    await insertNoteWithChildren();
    final violations = await db.customSelect('PRAGMA foreign_key_check').get();
    expect(violations, isEmpty);
  });
}
