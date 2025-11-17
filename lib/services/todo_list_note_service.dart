import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../dtos/note_folder_dto.dart';
import '../service_locators/init_service_locators.dart';
import '../sync/sync_manager.dart';

/// Service for managing todo list notes with items
/// Part of Architecture V8: Independent note types
class TodoListNoteService {
  TodoListNoteService._();

  /// Trigger background sync (non-blocking)
  static void _triggerBackgroundSync() {
    // Add delay to ensure current database transaction completes
    Future.delayed(const Duration(seconds: 1), () async {
      try {
        final syncManager = getIt<SyncManager>();
        debugPrint('🔄 [TodoListNoteService] Triggering background sync...');
        await syncManager.upload();
        debugPrint('✅ [TodoListNoteService] Background sync completed');
      } catch (e) {
        debugPrint('⚠️ [TodoListNoteService] Background sync failed: $e');
        // Don't rethrow - sync failures shouldn't affect note operations
      }
    });
  }

  /// Create a new todo list note
  ///
  /// IMPORTANT: folders parameter is REQUIRED (mandatory folders)
  /// If empty, defaults to "Random" folder
  static Future<int> createTodoListNote({
    required String title,
    required List<NoteFolderDto> folders,
    List<String>? initialItems,
    bool isPinned = false,
  }) async {
    try {
      final database = getIt<AppDatabase>();
      final now = DateTime.now();
      const uuid = Uuid();

      // Validate folders (must have at least one)
      if (folders.isEmpty) {
        throw Exception('Todo list note must belong to at least one folder');
      }

      final todoListNoteUuid = uuid.v4();

      // Create todo list note
      final todoListNoteId = await database.into(database.todoListNotesV2).insert(
        TodoListNotesV2Companion(
          uuid: Value(todoListNoteUuid),
          title: Value(title),
          isPinned: Value(isPinned),
          isArchived: const Value(false),
          isDeleted: const Value(false),
          isSynced: const Value(false), // Needs cloud sync
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Link to folders
      await _linkToFolders(todoListNoteId, folders);

      // Create initial items if provided
      if (initialItems != null && initialItems.isNotEmpty) {
        await _createInitialItems(todoListNoteId, todoListNoteUuid, initialItems);
      }

      debugPrint('✅ [TodoListNoteService] Created todo list note: $todoListNoteId with ${folders.length} folders and ${initialItems?.length ?? 0} items');

      // Trigger background sync
      _triggerBackgroundSync();

      return todoListNoteId;
    } catch (e, st) {
      debugPrint('❌ [TodoListNoteService] Failed to create todo list note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Update an existing todo list note
  static Future<void> updateTodoListNote({
    required int noteId,
    String? title,
    List<NoteFolderDto>? folders,
    bool? isPinned,
  }) async {
    try {
      final database = getIt<AppDatabase>();
      final now = DateTime.now();

      // Build update companion
      final companion = TodoListNotesV2Companion(
        title: title != null ? Value(title) : const Value.absent(),
        isPinned: isPinned != null ? Value(isPinned) : const Value.absent(),
        isSynced: const Value(false), // Mark for sync
        updatedAt: Value(now),
      );

      // Update note
      await (database.update(database.todoListNotesV2)
            ..where((t) => t.id.equals(noteId)))
          .write(companion);

      // Update folder relations if provided
      if (folders != null) {
        if (folders.isEmpty) {
          throw Exception('Todo list note must belong to at least one folder');
        }
        await _updateFolderRelations(noteId, folders);
      }

      debugPrint('✅ [TodoListNoteService] Updated todo list note: $noteId');

      // Trigger background sync
      _triggerBackgroundSync();
    } catch (e, st) {
      debugPrint('❌ [TodoListNoteService] Failed to update todo list note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Soft delete a todo list note
  static Future<void> deleteTodoListNote(int noteId) async {
    try {
      final database = getIt<AppDatabase>();
      final now = DateTime.now();

      await (database.update(database.todoListNotesV2)
            ..where((t) => t.id.equals(noteId)))
          .write(
        TodoListNotesV2Companion(
          isDeleted: const Value(true),
          isSynced: const Value(false), // Mark for sync
          updatedAt: Value(now),
        ),
      );

      debugPrint('✅ [TodoListNoteService] Soft deleted todo list note: $noteId');

      // Trigger background sync
      _triggerBackgroundSync();
    } catch (e, st) {
      debugPrint('❌ [TodoListNoteService] Failed to delete todo list note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Permanently delete a todo list note (hard delete)
  static Future<void> permanentlyDeleteTodoListNote(int noteId) async {
    try {
      final database = getIt<AppDatabase>();

      // Delete todo items (cascade)
      await (database.delete(database.todoItemsV2)
            ..where((t) => t.todoListNoteId.equals(noteId)))
          .go();

      // Delete folder relations (cascade)
      await (database.delete(database.todoListNoteFolderRelationsV2)
            ..where((t) => t.todoListNoteId.equals(noteId)))
          .go();

      // Delete note
      await (database.delete(database.todoListNotesV2)
            ..where((t) => t.id.equals(noteId)))
          .go();

      debugPrint('✅ [TodoListNoteService] Permanently deleted todo list note: $noteId');
    } catch (e, st) {
      debugPrint('❌ [TodoListNoteService] Failed to permanently delete todo list note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Get a single todo list note by ID
  static Future<TodoListNoteEntity?> getTodoListNote(int noteId) async {
    try {
      final database = getIt<AppDatabase>();
      return await (database.select(database.todoListNotesV2)
            ..where((t) => t.id.equals(noteId)))
          .getSingleOrNull();
    } catch (e, st) {
      debugPrint('❌ [TodoListNoteService] Failed to get todo list note: $e');
      debugPrint('Stack trace: $st');
      return null;
    }
  }

  /// Watch all todo list notes (excluding deleted)
  static Stream<List<TodoListNoteEntity>> watchAllTodoListNotes() {
    final database = getIt<AppDatabase>();
    return (database.select(database.todoListNotesV2)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Watch todo list notes by folder
  static Stream<List<TodoListNoteEntity>> watchTodoListNotesByFolder(int folderId) {
    final database = getIt<AppDatabase>();

    // Join with folder relations to filter by folder
    final query = database.select(database.todoListNotesV2).join([
      innerJoin(
        database.todoListNoteFolderRelationsV2,
        database.todoListNoteFolderRelationsV2.todoListNoteId.equalsExp(database.todoListNotesV2.id),
      ),
    ])
      ..where(database.todoListNoteFolderRelationsV2.folderId.equals(folderId))
      ..where(database.todoListNotesV2.isDeleted.equals(false))
      ..orderBy([
        OrderingTerm(expression: database.todoListNotesV2.isPinned, mode: OrderingMode.desc),
        OrderingTerm(expression: database.todoListNotesV2.updatedAt, mode: OrderingMode.desc),
      ]);

    return query.watch().map((rows) => rows.map((row) => row.readTable(database.todoListNotesV2)).toList());
  }

  // ==================== TODO ITEM OPERATIONS ====================

  /// Add a new item to a todo list
  static Future<int> addTodoItem({
    required int todoListNoteId,
    required String todoListNoteUuid,
    required String content,
  }) async {
    try {
      final database = getIt<AppDatabase>();
      final now = DateTime.now();
      const uuid = Uuid();

      final itemId = await database.into(database.todoItemsV2).insert(
        TodoItemsV2Companion(
          uuid: Value(uuid.v4()),
          todoListNoteId: Value(todoListNoteId),
          todoListNoteUuid: Value(todoListNoteUuid),
          content: Value(content),
          isCompleted: const Value(false),
          isSynced: const Value(false), // Needs cloud sync
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Mark parent todo list as needing sync
      await _markTodoListForSync(todoListNoteId);

      debugPrint('✅ [TodoListNoteService] Added todo item: $itemId to list: $todoListNoteId');
      return itemId;
    } catch (e, st) {
      debugPrint('❌ [TodoListNoteService] Failed to add todo item: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Update a todo item
  static Future<void> updateTodoItem({
    required int itemId,
    String? content,
    bool? isCompleted,
  }) async {
    try {
      final database = getIt<AppDatabase>();
      final now = DateTime.now();

      // Build update companion
      final companion = TodoItemsV2Companion(
        content: content != null ? Value(content) : const Value.absent(),
        isCompleted: isCompleted != null ? Value(isCompleted) : const Value.absent(),
        isSynced: const Value(false), // Mark for sync
        updatedAt: Value(now),
      );

      await (database.update(database.todoItemsV2)
            ..where((t) => t.id.equals(itemId)))
          .write(companion);

      // Get parent todo list and mark for sync
      final item = await (database.select(database.todoItemsV2)
            ..where((t) => t.id.equals(itemId)))
          .getSingleOrNull();

      if (item != null) {
        await _markTodoListForSync(item.todoListNoteId);
      }

      debugPrint('✅ [TodoListNoteService] Updated todo item: $itemId');
    } catch (e, st) {
      debugPrint('❌ [TodoListNoteService] Failed to update todo item: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Toggle todo item completion status
  static Future<void> toggleTodoItemCompletion(int itemId) async {
    try {
      final database = getIt<AppDatabase>();
      final now = DateTime.now();

      // Get current item
      final item = await (database.select(database.todoItemsV2)
            ..where((t) => t.id.equals(itemId)))
          .getSingleOrNull();

      if (item == null) {
        throw Exception('Todo item not found: $itemId');
      }

      // Toggle completion
      await (database.update(database.todoItemsV2)
            ..where((t) => t.id.equals(itemId)))
          .write(
        TodoItemsV2Companion(
          isCompleted: Value(!item.isCompleted),
          isSynced: const Value(false), // Mark for sync
          updatedAt: Value(now),
        ),
      );

      // Mark parent todo list for sync
      await _markTodoListForSync(item.todoListNoteId);

      debugPrint('✅ [TodoListNoteService] Toggled todo item completion: $itemId to ${!item.isCompleted}');
    } catch (e, st) {
      debugPrint('❌ [TodoListNoteService] Failed to toggle todo item: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Delete a todo item
  static Future<void> deleteTodoItem(int itemId) async {
    try {
      final database = getIt<AppDatabase>();

      // Get parent todo list before deleting
      final item = await (database.select(database.todoItemsV2)
            ..where((t) => t.id.equals(itemId)))
          .getSingleOrNull();

      // Delete item
      await (database.delete(database.todoItemsV2)
            ..where((t) => t.id.equals(itemId)))
          .go();

      // Mark parent todo list for sync
      if (item != null) {
        await _markTodoListForSync(item.todoListNoteId);
      }

      debugPrint('✅ [TodoListNoteService] Deleted todo item: $itemId');
    } catch (e, st) {
      debugPrint('❌ [TodoListNoteService] Failed to delete todo item: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Watch all items for a todo list
  static Stream<List<TodoItemEntity>> watchTodoItems(int todoListNoteId) {
    final database = getIt<AppDatabase>();
    return (database.select(database.todoItemsV2)
          ..where((t) => t.todoListNoteId.equals(todoListNoteId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  // ==================== PRIVATE HELPER METHODS ====================

  /// Link todo list note to folders
  static Future<void> _linkToFolders(int todoListNoteId, List<NoteFolderDto> folders) async {
    final database = getIt<AppDatabase>();

    await database.batch((batch) {
      for (final folder in folders) {
        batch.insert(
          database.todoListNoteFolderRelationsV2,
          TodoListNoteFolderRelationsV2Companion(
            todoListNoteId: Value(todoListNoteId),
            folderId: Value(folder.id),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// Update folder relations for a todo list note
  static Future<void> _updateFolderRelations(int todoListNoteId, List<NoteFolderDto> folders) async {
    final database = getIt<AppDatabase>();

    await database.transaction(() async {
      // Delete existing relations
      await (database.delete(database.todoListNoteFolderRelationsV2)
            ..where((t) => t.todoListNoteId.equals(todoListNoteId)))
          .go();

      // Add new relations
      await _linkToFolders(todoListNoteId, folders);
    });
  }

  /// Create initial todo items
  static Future<void> _createInitialItems(int todoListNoteId, String todoListNoteUuid, List<String> items) async {
    final database = getIt<AppDatabase>();
    final now = DateTime.now();
    const uuid = Uuid();

    await database.batch((batch) {
      for (final content in items) {
        batch.insert(
          database.todoItemsV2,
          TodoItemsV2Companion(
            uuid: Value(uuid.v4()),
            todoListNoteId: Value(todoListNoteId),
            todoListNoteUuid: Value(todoListNoteUuid),
            content: Value(content),
            isCompleted: const Value(false),
            isSynced: const Value(false),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  /// Mark parent todo list as needing sync
  static Future<void> _markTodoListForSync(int todoListNoteId) async {
    final database = getIt<AppDatabase>();
    final now = DateTime.now();

    await (database.update(database.todoListNotesV2)
          ..where((t) => t.id.equals(todoListNoteId)))
        .write(
      TodoListNotesV2Companion(
        isSynced: const Value(false),
        updatedAt: Value(now),
      ),
    );
  }
}
