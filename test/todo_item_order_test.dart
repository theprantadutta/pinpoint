import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/dtos/note_folder_dto.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/drift_note_folder_service.dart';
import 'package:pinpoint/services/todo_list_note_service.dart';

/// The checklist editor's manual order.
///
/// Tasks are listed by `orderIndex` (which already travels inside the
/// encrypted note payload) and then by creation, so lists written before
/// ordering existed — every item at index 0 — keep their creation order,
/// new tasks land at the end, and a drag-reorder persists.
void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    if (getIt.isRegistered<AppDatabase>()) {
      getIt.unregister<AppDatabase>();
    }
    getIt.registerSingleton<AppDatabase>(database);
  });

  tearDown(() async {
    getIt.unregister<AppDatabase>();
    await database.close();
  });

  Future<(int, String)> newList(List<String> items) async {
    final folder = await DriftNoteFolderService.insertNoteFolder('Lists');
    final id = await TodoListNoteService.createTodoListNote(
      title: 'Groceries',
      folders: [NoteFolderDto(id: folder.id, title: folder.title)],
      initialItems: items,
    );
    final note = await TodoListNoteService.getTodoListNote(id);
    return (id, note!.uuid);
  }

  Future<List<String>> texts(int listId) async => [
        for (final i in await TodoListNoteService.watchTodoItems(listId).first)
          i.content,
      ];

  test('initial items keep their order and new ones go last', () async {
    final (id, uuid) = await newList(['Milk', 'Eggs', 'Bread']);
    await TodoListNoteService.addTodoItem(
        todoListNoteId: id, todoListNoteUuid: uuid, content: 'Coffee');

    expect(await texts(id), ['Milk', 'Eggs', 'Bread', 'Coffee']);
    final items = await TodoListNoteService.watchTodoItems(id).first;
    expect([for (final i in items) i.orderIndex], [0, 1, 2, 3]);
  });

  test('a reorder persists and marks the list for sync', () async {
    final (id, _) = await newList(['Milk', 'Eggs', 'Bread']);
    final before = await TodoListNoteService.watchTodoItems(id).first;
    await (database.update(database.todoListNotesV2))
        .write(const TodoListNotesV2Companion(isSynced: Value(true)));

    await TodoListNoteService.reorderTodoItems(
        id, [before[2].id, before[0].id, before[1].id]);

    expect(await texts(id), ['Bread', 'Milk', 'Eggs']);
    final list = await TodoListNoteService.getTodoListNote(id);
    expect(list!.isSynced, isFalse);
  });

  test('legacy items all at index 0 fall back to creation order', () async {
    final (id, uuid) = await newList([]);
    for (final text in ['First', 'Second', 'Third']) {
      await TodoListNoteService.addTodoItem(
        todoListNoteId: id,
        todoListNoteUuid: uuid,
        content: text,
        orderIndex: 0,
      );
    }
    expect(await texts(id), ['First', 'Second', 'Third']);
  });

  test('an undone delete can restore an item with its state and place',
      () async {
    final (id, uuid) = await newList(['Milk', 'Eggs']);
    final items = await TodoListNoteService.watchTodoItems(id).first;
    await TodoListNoteService.deleteTodoItem(items.first.id);

    final restored = await TodoListNoteService.addTodoItem(
      todoListNoteId: id,
      todoListNoteUuid: uuid,
      content: 'Milk',
      isCompleted: true,
      orderIndex: 0,
    );
    await TodoListNoteService.reorderTodoItems(id, [restored, items[1].id]);

    final after = await TodoListNoteService.watchTodoItems(id).first;
    expect([for (final i in after) i.content], ['Milk', 'Eggs']);
    expect(after.first.isCompleted, isTrue);
  });
}
