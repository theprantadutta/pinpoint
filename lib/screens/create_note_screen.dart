// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image_picker/image_picker.dart';

import '../components/create_note_screen/show_note_folder_bottom_sheet.dart';
import '../components/create_note_screen/record_audio_type/record_type_content.dart';
import '../components/create_note_screen/reminder_type/reminder_type_content.dart';
import '../components/create_note_screen/todo_list_type/todo_list_type_content.dart';
import '../constants/constants.dart';
import '../database/database.dart' as db;
import '../dtos/note_attachment_dto.dart';
import '../dtos/note_folder_dto.dart';
import '../services/drift_note_folder_service.dart';
import '../services/drift_note_service.dart';
import '../services/premium_service.dart';
import '../services/background_save_queue_service.dart';
import '../services/ocr_service.dart';
import '../service_locators/init_service_locators.dart';
import '../sync/sync_manager.dart';
import '../widgets/premium_gate_dialog.dart';
import '../constants/premium_limits.dart';
import '../util/show_a_toast.dart';
import '../design_system/design_system.dart';

class CreateNoteScreen extends StatefulWidget {
  static const String kRouteName = '/create-note';
  final CreateNoteScreenArguments? args;

  const CreateNoteScreen({
    super.key,
    required this.args,
  });

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen>
    with WidgetsBindingObserver {
  String selectedNoteType = kNoteTypes[0];
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _reminderDescription;
  late SharePlus _sharePlus;

  List<NoteFolderDto> selectedFolders = [
    DriftNoteFolderService.firstNoteFolder
  ];
  List<db.NoteTodoItem> todos = [];
  List<db.NoteTodoItem> _savedTodos = []; // Track previously saved todos
  DateTime? reminderDateTime;
  List<NoteAttachmentDto> noteAttachments = [];
  int? _currentNoteId; // Track the note ID after first save

  final ScrollController _scrollController = ScrollController();
  final FocusNode _contentFocusNode = FocusNode();
  Timer? _autoSaveTimer;
  late final BackgroundSaveQueueService _saveQueue;
  bool _isSavingTodos = false; // Prevent concurrent todo saves

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _saveQueue = getIt<BackgroundSaveQueueService>();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
    _reminderDescription = TextEditingController();
    _sharePlus = SharePlus.instance;

    // Add auto-save listeners
    _titleController.addListener(_scheduleAutoSave);
    _contentController.addListener(_scheduleAutoSave);
    _reminderDescription.addListener(_scheduleAutoSave);

    if (widget.args?.existingNote != null) {
      final existingNote = widget.args!.existingNote!;
      _currentNoteId = existingNote.note.id;
      selectedNoteType = getNoteTypeDisplayName(existingNote.note.noteType);
      _titleController.text = existingNote.note.noteTitle ?? '';

      // Load type-specific data
      if (selectedNoteType == kNoteTypes[0]) {
        // Text note - load content from TextNotes table
        _contentController.text = existingNote.textContent ?? '';
      }

      selectedFolders = existingNote.folders;
      todos = List<db.NoteTodoItem>.from(existingNote.todoItems);
      _savedTodos = List<db.NoteTodoItem>.from(existingNote.todoItems);
      // TODO: Load reminder data from ReminderNotes table if type is 'reminder'
      _reminderDescription.text = '';
      reminderDateTime = null;
    } else if (widget.args?.noticeType != null) {
      // Pre-select note type for new notes (e.g., from Todo screen)
      selectedNoteType = widget.args!.noticeType;
    }
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _autoSaveNote();
      }
    });
  }

  Future<void> _autoSaveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // Check if there's any content to save based on note type
    final hasTextContent = title.isNotEmpty || content.isNotEmpty;
    final hasTodos = selectedNoteType == kNoteTypes[2] && todos.isNotEmpty;
    final hasReminder =
        selectedNoteType == kNoteTypes[3] && reminderDateTime != null;

    debugPrint(
        'Auto-save triggered: noteType=$selectedNoteType, hasTextContent=$hasTextContent, hasTodos=$hasTodos (${todos.length} todos), hasReminder=$hasReminder');

    // Don't save if there's nothing to save
    if (!hasTextContent && !hasTodos && !hasReminder) {
      debugPrint('Auto-save skipped: nothing to save');
      return;
    }

    debugPrint('Auto-save executing via background queue...');

    final now = DateTime.now();
    final noteCompanion = db.NotesCompanion.insert(
      noteTitle: drift.Value(title),
      isPinned: drift.Value(false),
      noteType: getNoteTypeDbValue(selectedNoteType),
      createdAt: now,
      updatedAt: now,
    );

    // Enqueue save WITHOUT awaiting - fire and forget for auto-save
    _saveQueue
        .enqueueSave(
      noteCompanion: noteCompanion,
      previousNoteId: _currentNoteId,
      folders: selectedFolders,
    )
        .then((result) async {
      if (result.success) {
        debugPrint('Auto-save completed: note ID ${result.noteId}');
        final noteId = result.noteId;

        // Update current note ID if this was a new note
        if (_currentNoteId == null && mounted) {
          setState(() {
            _currentNoteId = noteId;
          });
        }

        // Save type-specific data
        // Save text content if this is a text note
        if (selectedNoteType == kNoteTypes[0] && content.isNotEmpty) {
          await _saveTextContent(noteId, content);
        }

        // Save todos if this is a todo list note
        if (selectedNoteType == kNoteTypes[2] && todos.isNotEmpty) {
          await _saveTodos(noteId);
        }

        // TODO: Save reminder data if this is a reminder note
        // TODO: Save audio data if this is an audio note

        // Upload to cloud after save completes
        _uploadToCloudInBackground();
      } else {
        debugPrint('Auto-save failed: ${result.reason}');
        // Optionally show subtle error indicator (not intrusive toast)
      }
    });

    debugPrint('Auto-save enqueued');
  }

  /// Upload note to cloud in background (non-blocking)
  Future<void> _uploadToCloudInBackground() async {
    try {
      if (_currentNoteId == null) {
        debugPrint('☁️ [Auto-Upload] Skipping upload: no note ID yet');
        return;
      }

      final syncManager = getIt<SyncManager>();
      debugPrint('☁️ [Auto-Upload] Uploading note $_currentNoteId to cloud...');

      // Fire and forget - don't block UI or wait for result
      syncManager.upload().then((result) {
        if (result.success) {
          debugPrint('✅ [Auto-Upload] Note uploaded successfully: ${result.message}');
        } else {
          debugPrint('⚠️ [Auto-Upload] Upload failed: ${result.message}');
        }
      }).catchError((e) {
        debugPrint('❌ [Auto-Upload] Upload error: $e');
      });
    } catch (e) {
      debugPrint('❌ [Auto-Upload] Exception during upload: $e');
    }
  }

  Future<void> _saveTextContent(int noteId, String content) async {
    try {
      debugPrint('[Auto-save Text] Saving text content for note $noteId');

      final database = getIt<db.AppDatabase>();

      // Check if TextNote record already exists
      final existingTextNote = await (database.select(database.textNotes)
            ..where((t) => t.noteId.equals(noteId)))
          .getSingleOrNull();

      if (existingTextNote != null) {
        // Update existing text content
        debugPrint('[Auto-save Text] Updating existing text content');
        await (database.update(database.textNotes)
              ..where((t) => t.noteId.equals(noteId)))
            .write(db.TextNotesCompanion(
          content: drift.Value(content),
        ));
      } else {
        // Insert new text content
        debugPrint('[Auto-save Text] Inserting new text content');
        await database.into(database.textNotes).insert(
              db.TextNotesCompanion(
                noteId: drift.Value(noteId),
                content: drift.Value(content),
              ),
            );
      }

      // CRITICAL: Update parent note's updated_at timestamp and mark as unsynced
      // This triggers Drift streams watching the notes table to refresh UI
      await (database.update(database.notes)
            ..where((n) => n.id.equals(noteId)))
          .write(db.NotesCompanion(
        updatedAt: drift.Value(DateTime.now()),
        isSynced: drift.Value(false), // Mark as needing upload
      ));

      debugPrint('[Auto-save Text] Text content saved successfully');
    } catch (e, st) {
      debugPrint('[Auto-save Text] Error saving text content: $e');
      debugPrint('[Auto-save Text] Stack trace: $st');
    }
  }

  Future<void> _saveTodos(int noteId) async {
    // Prevent concurrent saves
    if (_isSavingTodos) {
      debugPrint('[Auto-save Todos] Save already in progress, skipping');
      return;
    }

    _isSavingTodos = true;
    try {
      debugPrint(
          '[Auto-save Todos] Saving todos: ${todos.length} total, ${_savedTodos.length} previously saved');

      // Snapshot current todos to avoid race conditions
      final todosSnapshot = List<db.NoteTodoItem>.from(todos);
      final newTodos = todosSnapshot.where((todo) => todo.id < 0).toList();
      final existingTodos = todosSnapshot.where((todo) => todo.id > 0).toList();

      debugPrint(
          '[Auto-save Todos] ${newTodos.length} new todos, ${existingTodos.length} existing todos');

      // Delete todos that were removed
      for (var savedTodo in _savedTodos) {
        final stillExists = todosSnapshot.any((t) => t.id == savedTodo.id);
        if (!stillExists) {
          debugPrint(
              '[Auto-save Todos] Deleting todo ${savedTodo.id}: ${savedTodo.todoTitle}');
          await DriftNoteService.deleteTodoItem(savedTodo.id);
        }
      }

      // Insert new todos and update their IDs
      for (var todo in newTodos) {
        debugPrint('[Auto-save Todos] Inserting new todo: ${todo.todoTitle}');
        final insertedTodo = await DriftNoteService.insertTodoItem(
          noteId: noteId,
          title: todo.todoTitle,
        );
        debugPrint('[Auto-save Todos] Inserted with ID: ${insertedTodo.id}');
        // Update the todo item with the real ID in the live list
        final index = todos.indexWhere((t) => t.id == todo.id);
        if (index != -1) {
          todos[index] = insertedTodo.copyWith(isDone: todo.isDone);
        }
      }

      // Update existing todos
      for (var todo in existingTodos) {
        final wasPreviouslySaved = _savedTodos.any((t) => t.id == todo.id);
        if (wasPreviouslySaved) {
          debugPrint(
              '[Auto-save Todos] Updating todo ${todo.id}: ${todo.todoTitle}, isDone=${todo.isDone}');
          await DriftNoteService.updateTodoItemTitle(todo.id, todo.todoTitle);
          await DriftNoteService.updateTodoItemStatus(todo.id, todo.isDone);
        } else {
          debugPrint(
              '[Auto-save Todos] Unexpected: existing todo ${todo.id} not in saved list, inserting');
          await DriftNoteService.insertTodoItem(
            noteId: noteId,
            title: todo.todoTitle,
          );
        }
      }

      // Update the saved todos list with the current snapshot
      if (mounted) {
        setState(() {
          _savedTodos = List<db.NoteTodoItem>.from(todos);
        });
      }

      // CRITICAL: Update parent note's updated_at timestamp
      // This triggers Drift streams watching the notes table to refresh UI
      final database = getIt<db.AppDatabase>();
      await (database.update(database.notes)
            ..where((n) => n.id.equals(noteId)))
          .write(db.NotesCompanion(
        updatedAt: drift.Value(DateTime.now()),
      ));

      debugPrint('[Auto-save Todos] Todo save completed successfully');
    } catch (e) {
      debugPrint('[Auto-save Todos] Error saving todos: $e');
    } finally {
      _isSavingTodos = false;
    }
  }

  void _onTodoChanged(List<db.NoteTodoItem> newTodoItems) {
    setState(() => todos = newTodoItems);
    _scheduleAutoSave();
  }

  void _onReminderDateTimeChanged(DateTime selectedDateTime) {
    setState(() => reminderDateTime = selectedDateTime);
    _scheduleAutoSave();
  }

  void _onFoldersChanged(List<NoteFolderDto> folders) {
    setState(() => selectedFolders = folders);
    _scheduleAutoSave();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveTimer?.cancel();
    _titleController.removeListener(_scheduleAutoSave);
    _contentController.removeListener(_scheduleAutoSave);
    _reminderDescription.removeListener(_scheduleAutoSave);
    _scrollController.dispose();
    _contentFocusNode.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _reminderDescription.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // App going to background or being terminated - trigger save via queue
      debugPrint('[Lifecycle] App state changed to $state, triggering save via queue');

      // Cancel any pending auto-save timer
      _autoSaveTimer?.cancel();

      // Trigger save via queue (fire and forget, queue will handle it)
      _performImmediateSaveViaQueue();
    }
  }

  Future<void> _performImmediateSaveViaQueue() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // Check if there's any content to save
    final hasTextContent = title.isNotEmpty || content.isNotEmpty;
    final hasTodos = selectedNoteType == kNoteTypes[2] && todos.isNotEmpty;
    final hasReminder =
        selectedNoteType == kNoteTypes[3] && reminderDateTime != null;

    if (!hasTextContent && !hasTodos && !hasReminder) {
      debugPrint('[ImmediateSave] No content to save, skipping');
      return;
    }

    debugPrint('[ImmediateSave] Saving via queue...');

    try {
      final now = DateTime.now();
      final noteCompanion = db.NotesCompanion.insert(
        noteTitle: drift.Value(title),
        isPinned: drift.Value(false),
        noteType: getNoteTypeDbValue(selectedNoteType),
        createdAt: now,
        updatedAt: now,
      );

      // Use queue but AWAIT the result (blocks navigation until complete)
      final result = await _saveQueue.enqueueSave(
        noteCompanion: noteCompanion,
        previousNoteId: _currentNoteId,
        folders: selectedFolders, // Save folders too!
        debounce: false, // No debounce for immediate saves
      );

      if (result.success) {
        debugPrint('[ImmediateSave] Save completed: note ID ${result.noteId}');
        final noteId = result.noteId;

        if (_currentNoteId == null && mounted) {
          setState(() {
            _currentNoteId = noteId;
          });
        }

        // Save type-specific data
        // Save text content if this is a text note
        if (selectedNoteType == kNoteTypes[0] && content.isNotEmpty) {
          await _saveTextContent(noteId, content);
        }

        // Save todos if this is a todo list note
        if (selectedNoteType == kNoteTypes[2] && todos.isNotEmpty) {
          await _saveTodos(noteId);
        }

        // Upload to cloud after save completes
        _uploadToCloudInBackground();
      } else {
        debugPrint('[ImmediateSave] Save failed: ${result.reason}');
      }
    } catch (e) {
      debugPrint('[ImmediateSave] Error during save: $e');
    }
  }

  Future<void> saveNoteToLocalDb({bool showToast = true}) async {
    try {
      final title = _titleController.text.trim();
      final content = _contentController.text.trim();

      // Validate based on note type
      if (selectedNoteType == kNoteTypes[2] && todos.isEmpty) {
        if (showToast) {
          _showErrorToast(
              'Failed to save Note!', 'Please add at least one todo item');
        }
        return;
      }

      if (selectedNoteType == kNoteTypes[0] &&
          title.isEmpty &&
          content.isEmpty) {
        if (showToast) {
          _showErrorToast('Failed to save Note!',
              'Please provide at least a title or content');
        }
        return;
      }

      if (selectedNoteType == kNoteTypes[3] && reminderDateTime == null) {
        if (showToast) {
          _showErrorToast('Failed to save Note!', 'Please set a reminder time');
        }
        return;
      }

      final now = DateTime.now();
      final noteCompanion = db.NotesCompanion.insert(
        noteTitle: drift.Value(title),
        isPinned: drift.Value(false),
        noteType: getNoteTypeDbValue(selectedNoteType),
        createdAt: now,
        updatedAt: now,
      );

      // For explicit saves, AWAIT the result from the queue
      final result = await _saveQueue.enqueueSave(
        noteCompanion: noteCompanion,
        previousNoteId: _currentNoteId,
        debounce: false, // No debounce for explicit saves
      );

      if (!result.success) {
        _showErrorToast('Failed to save Note!',
            result.reason ?? 'Something went wrong while saving the note');
        return;
      }

      final noteId = result.noteId;

      // Update the current note ID after first save
      if (_currentNoteId == null) {
        setState(() {
          _currentNoteId = noteId;
        });
      }

      // Save type-specific data
      // Save text content if this is a text note
      if (selectedNoteType == kNoteTypes[0] && content.isNotEmpty) {
        await _saveTextContent(noteId, content);
      }

      // Save todos
      if (selectedNoteType == kNoteTypes[2]) {
        debugPrint(
            'Saving todos: ${todos.length} total, ${_savedTodos.length} previously saved');
        final newTodos = todos.where((todo) => todo.id < 0).toList();
        final existingTodos = todos.where((todo) => todo.id > 0).toList();
        debugPrint(
            '  - ${newTodos.length} new todos, ${existingTodos.length} existing todos');

        // Delete todos that were removed
        for (var savedTodo in _savedTodos) {
          final stillExists = todos.any((t) => t.id == savedTodo.id);
          if (!stillExists) {
            debugPrint(
                '  - Deleting todo ${savedTodo.id}: ${savedTodo.todoTitle}');
            await DriftNoteService.deleteTodoItem(savedTodo.id);
          }
        }

        // Insert new todos and update their IDs
        for (var todo in newTodos) {
          debugPrint('  - Inserting new todo: ${todo.todoTitle}');
          final insertedTodo = await DriftNoteService.insertTodoItem(
            noteId: noteId,
            title: todo.todoTitle,
          );
          debugPrint('    - Inserted with ID: ${insertedTodo.id}');
          // Update the todo item with the real ID
          final index = todos.indexWhere((t) => t.id == todo.id);
          if (index != -1) {
            todos[index] = insertedTodo.copyWith(isDone: todo.isDone);
          }
        }

        // Update existing todos
        for (var todo in existingTodos) {
          final wasPreviouslySaved = _savedTodos.any((t) => t.id == todo.id);
          if (wasPreviouslySaved) {
            debugPrint(
                '  - Updating todo ${todo.id}: ${todo.todoTitle}, isDone=${todo.isDone}');
            await DriftNoteService.updateTodoItemTitle(todo.id, todo.todoTitle);
            await DriftNoteService.updateTodoItemStatus(todo.id, todo.isDone);
          } else {
            // This shouldn't happen but handle it just in case
            debugPrint(
                '  - Unexpected: existing todo ${todo.id} not in saved list, inserting');
            await DriftNoteService.insertTodoItem(
              noteId: noteId,
              title: todo.todoTitle,
            );
          }
        }

        // Update the saved todos list
        setState(() {
          _savedTodos = List<db.NoteTodoItem>.from(todos);
        });
        debugPrint('Todo save completed successfully');
      }

      // Save folders
      final foldersResult = await DriftNoteFolderService.upsertNoteFoldersWithNote(
        selectedFolders,
        noteId,
      );

      if (!foldersResult) {
        _showErrorToast(
            'Failed to save folders!', 'Some folders may not have been saved.');
      }

      // Save attachments
      final attachmentsUpdated =
          await DriftNoteService.upsertNoteAttachments(noteAttachments, noteId);
      if (!attachmentsUpdated) {
        _showErrorToast('Failed to save Attachments!',
            'Some attachments may not have been saved.');
      }

      if (showToast) {
        PinpointHaptics.success();
        _showSuccessToast(
            'Note Saved Successfully!', 'Your note was successfully saved!');
        Navigator.of(context).pop();
      }
    } catch (e, stackTrace) {
      debugPrint('Error saving note: $e');
      debugPrint('Stack trace: $stackTrace');
      if (showToast) {
        _showErrorToast('Failed to save Note!', 'Error: ${e.toString()}');
      }
    }
  }

  void _showErrorToast(String title, String description) {
    showErrorToast(context: context, title: title, description: description);
  }

  void _showSuccessToast(String title, String description) {
    showSuccessToast(context: context, title: title, description: description);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: BackButtonListener(
        onBackButtonPressed: () async {
          debugPrint('[BackButton] Back button pressed, triggering save...');

          // Cancel pending auto-save timer
          _autoSaveTimer?.cancel();

          // Trigger immediate save via queue
          await _performImmediateSaveViaQueue();

          debugPrint('[BackButton] Save completed, allowing navigation');
          return false; // Allow navigation
        },
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Modern Header
              _buildHeader(context, cs, isDark),

              // Content
              Expanded(
                child: CustomScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    // Metadata Section (Folders & Tags)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: _buildMetadataSection(cs, isDark),
                      ),
                    ),

                    // Content Area - Based on note type
                    _buildContentArea(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: cs.outline.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back Button
          IconButton(
            icon: Icon(Symbols.arrow_back, color: cs.onSurface),
            iconSize: 24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            onPressed: () async {
              PinpointHaptics.light();
              debugPrint('[HeaderBackButton] Back button clicked, triggering save...');

              // Cancel pending auto-save timer
              _autoSaveTimer?.cancel();

              // Trigger immediate save via queue
              await _performImmediateSaveViaQueue();

              debugPrint('[HeaderBackButton] Save completed, navigating back');
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          ),

          // Title Input - Pill-shaped with better padding
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Untitled',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  hintStyle: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                textInputAction: TextInputAction.done,
              ),
            ),
          ),

          // More Options Button
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: cs.onSurface),
            iconSize: 24,
            padding: EdgeInsets.zero,
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) {
              PinpointHaptics.light();
              switch (value) {
                case 'delete':
                  _handleDeleteNote(context, cs);
                  break;
                case 'share':
                  _handleShareNote(context);
                  break;
                case 'export_markdown':
                  _handleExportMarkdown(context);
                  break;
                case 'export_pdf':
                  _handleExportPdf(context);
                  break;
                case 'ocr_scan':
                  _handleOcrScan(context);
                  break;
                case 'info':
                  _showNoteInfoModal(context, cs, isDark);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 20, color: cs.error),
                    const SizedBox(width: 12),
                    const Text('Delete'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Symbols.share, size: 20, color: cs.primary),
                    const SizedBox(width: 12),
                    const Text('Share'),
                  ],
                ),
              ),
              // OCR Scan
              PopupMenuItem(
                value: 'ocr_scan',
                child: Row(
                  children: [
                    Icon(Icons.document_scanner_rounded,
                        size: 20, color: cs.primary),
                    const SizedBox(width: 12),
                    Builder(
                      builder: (context) {
                        final premiumService = PremiumService();
                        final isPremium = premiumService.isPremium;
                        final used = premiumService.getOcrScansThisMonth();
                        final total = PremiumLimits.maxOcrScansPerMonthForFree;

                        String ocrText = 'Scan Text from Image';
                        if (!isPremium) {
                          ocrText = 'Scan Text ($used/$total)';
                        }

                        return Text(ocrText);
                      },
                    ),
                  ],
                ),
              ),
              // Markdown Export
              PopupMenuItem(
                value: 'export_markdown',
                child: Row(
                  children: [
                    Icon(Icons.file_download_rounded,
                        size: 20, color: cs.primary),
                    const SizedBox(width: 12),
                    const Text('Export Markdown'),
                    const SizedBox(width: 4),
                    if (!PremiumService().isPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: PinpointColors.mint.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'PRO',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: PinpointColors.mint,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // PDF Export
              PopupMenuItem(
                value: 'export_pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded,
                        size: 20, color: cs.primary),
                    const SizedBox(width: 12),
                    const Text('Export PDF'),
                    const SizedBox(width: 4),
                    if (!PremiumService().isPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: PinpointColors.mint.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'PRO',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: PinpointColors.mint,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Encrypted Sharing (Coming Soon)
              PopupMenuItem(
                enabled: false,
                child: Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
                    const SizedBox(width: 12),
                    Text(
                      'Share Encrypted',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'SOON',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 20, color: cs.primary),
                    const SizedBox(width: 12),
                    const Text('Info'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentArea() {
    switch (selectedNoteType) {
      case 'Title Content':
        return _buildSimpleTextField();
      case 'Record Audio':
        return RecordTypeContent(
          onTranscribedText: (transcribedText) {
            if (!mounted) return;
            _contentController.text += transcribedText;
          },
        );
      case 'Todo List':
        return TodoListTypeContent(
          todos: todos,
          onTodoChanged: _onTodoChanged,
        );
      case 'Reminder':
        return ReminderTypeContent(
          descriptionController: _reminderDescription,
          selectedDateTime: reminderDateTime,
          onReminderDateTimeChanged: _onReminderDateTimeChanged,
        );
      default:
        return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
  }

  Widget _buildSimpleTextField() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TextField(
          controller: _contentController,
          focusNode: _contentFocusNode,
          decoration: InputDecoration(
            hintText: 'Start writing your note...',
            filled: true,
            fillColor: isDark
                ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                : cs.surfaceContainerHighest.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: cs.outline.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: cs.outline.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: cs.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            hintStyle: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.4),
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.6,
            letterSpacing: 0.2,
            fontSize: 16,
          ),
          maxLines: null,
          textInputAction: TextInputAction.newline,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
        ),
      ),
    );
  }

  Widget _buildMetadataSection(ColorScheme cs, bool isDark) {
    final now = DateTime.now();
    final timeFormat =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateFormat = '${_getMonthName(now.month)} ${now.day}, ${now.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date and Time Row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: cs.outline.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.7),
                          letterSpacing: 0.2,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: cs.outline.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeFormat,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.7),
                          letterSpacing: 0.2,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Note Type and Folder Row
        Row(
          children: [
            // Note Type Bubble
            Flexible(
              child: _buildFloatingBubble(
                label: _getLabelForNoteType(selectedNoteType),
                icon: _getIconForNoteType(selectedNoteType),
                color: cs.primary,
                cs: cs,
                isDark: isDark,
                onTap: () {
                  PinpointHaptics.light();
                  _showNoteTypeBottomSheet(cs, isDark);
                },
              ),
            ),

            const SizedBox(width: 12),

            // Folder Bubble
            Flexible(
              child: _buildFloatingBubble(
                label: selectedFolders.isEmpty
                    ? 'Add Folder'
                    : selectedFolders.first.title,
                icon: Symbols.folder,
                color: cs.secondary,
                cs: cs,
                isDark: isDark,
                onTap: () async {
                  PinpointHaptics.light();
                  final allFolders =
                      await DriftNoteFolderService.watchAllNoteFoldersStream()
                          .first;
                  if (!context.mounted) return;
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => Container(
                      height: MediaQuery.of(context).size.height * 0.65,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28)),
                      ),
                      child: ShowNoteFolderBottomSheet(
                        selectedFolders: selectedFolders,
                        setSelectedFolders: _onFoldersChanged,
                        noteFolderData: allFolders,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        // Additional folders as mini bubbles
        if (selectedFolders.length > 1) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedFolders
                .skip(1)
                .map((folder) => _buildMiniBubble(
                      label: folder.title,
                      color: cs.secondary,
                      cs: cs,
                      isDark: isDark,
                      onTap: () async {
                        PinpointHaptics.light();
                        final allFolders = await DriftNoteFolderService
                                .watchAllNoteFoldersStream()
                            .first;
                        if (!context.mounted) return;
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => Container(
                            height: MediaQuery.of(context).size.height * 0.65,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(28)),
                            ),
                            child: ShowNoteFolderBottomSheet(
                              selectedFolders: selectedFolders,
                              setSelectedFolders: _onFoldersChanged,
                              noteFolderData: allFolders,
                            ),
                          ),
                        );
                      },
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  Widget _buildFloatingBubble({
    required String label,
    required IconData icon,
    required Color color,
    required ColorScheme cs,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: isDark ? 0.2 : 0.15),
              color.withValues(alpha: isDark ? 0.1 : 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.3 : 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                      letterSpacing: 0.2,
                    ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBubble({
    required String label,
    required Color color,
    required ColorScheme cs,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.8),
              ),
        ),
      ),
    );
  }

  void _showNoteTypeBottomSheet(ColorScheme cs, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Note Type',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 24),
            ...kNoteTypes.map((type) {
              final isSelected = selectedNoteType == type;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(_getIconForNoteType(type), color: cs.primary),
                  title: Text(_getLabelForNoteType(type)),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: cs.primary)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: cs.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  selected: isSelected,
                  onTap: () {
                    PinpointHaptics.light();
                    setState(() => selectedNoteType = type);
                    Navigator.pop(context);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _handleDeleteNote(BuildContext context, ColorScheme cs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text(
            'Are you sure you want to delete this note? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Delete the note if it has an ID (i.e., it's been saved)
              if (widget.args?.existingNote != null) {
                final noteId = widget.args!.existingNote!.note.id;
                await DriftNoteService.softDeleteNoteById(noteId);
              }
              if (!context.mounted) return;
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close note screen
            },
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleShareNote(BuildContext context) async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nothing to Share'),
          content: const Text('Please add some content before sharing.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Share the note
    _sharePlus.share(ShareParams(
      text: '$title\n\n$content',
      subject: title,
    ));

    // Show success feedback
    PinpointHaptics.success();
  }

  Future<void> _handleExportMarkdown(BuildContext context) async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nothing to Export'),
          content: const Text('Please add some content before exporting.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Check export limits for free users
    final premiumService = PremiumService();
    if (!premiumService.isPremium) {
      if (!premiumService.canExport()) {
        if (mounted) {
          PremiumGateDialog.showExportLimit(context);
        }
        return;
      }
    }

    try {
      // Format as markdown
      final markdown = StringBuffer();

      // Add title as H1
      if (title.isNotEmpty) {
        markdown.writeln('# $title');
        markdown.writeln();
      }

      // Add content
      if (content.isNotEmpty) {
        markdown.writeln(content);
      }

      // Add todo items if this is a todo note
      if (selectedNoteType == kNoteTypes[2] && todos.isNotEmpty) {
        markdown.writeln();
        markdown.writeln('## Tasks');
        markdown.writeln();
        for (final todo in todos) {
          final checkbox = todo.isDone ? '[x]' : '[ ]';
          markdown.writeln('- $checkbox ${todo.todoTitle}');
        }
      }

      // Add metadata
      markdown.writeln();
      markdown.writeln('---');
      markdown.writeln('*Exported from Pinpoint*');
      markdown.writeln('*Date: ${DateTime.now().toString().split('.')[0]}*');

      // Save as file
      final directory = await getTemporaryDirectory();
      final fileName = title.isNotEmpty
          ? '${title.replaceAll(RegExp(r'[^\w\s-]'), '')}.md'
          : 'note_${DateTime.now().millisecondsSinceEpoch}.md';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(markdown.toString());

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: title.isNotEmpty ? title : 'Exported Note',
      );

      // Increment export counter for free users
      if (!premiumService.isPremium) {
        await premiumService.incrementExports();
      }

      PinpointHaptics.success();

      if (mounted) {
        showSuccessToast(
          context: context,
          title: 'Exported!',
          description: 'Markdown file exported successfully',
        );
      }
    } catch (e) {
      debugPrint('Error exporting markdown: $e');
      PinpointHaptics.error();

      if (mounted) {
        showErrorToast(
          context: context,
          title: 'Export Failed',
          description: 'Unable to export markdown file',
        );
      }
    }
  }

  Future<void> _handleExportPdf(BuildContext context) async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nothing to Export'),
          content: const Text('Please add some content before exporting.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Check export limits for free users
    final premiumService = PremiumService();
    if (!premiumService.isPremium) {
      if (!premiumService.canExport()) {
        if (mounted) {
          PremiumGateDialog.showExportLimit(context);
        }
        return;
      }
    }

    try {
      // Create PDF document
      final pdf = pw.Document();

      // Add a page with simple text content
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Title
                if (title.isNotEmpty) ...[
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],
                // Content
                if (content.isNotEmpty) ...[
                  pw.Text(
                    content,
                    style: const pw.TextStyle(
                      fontSize: 12,
                      lineSpacing: 1.5,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],
                // Metadata
                pw.Spacer(),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Exported from Pinpoint',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
                pw.Text(
                  'Date: ${DateTime.now().toString().split('.')[0]}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Save to file
      final directory = await getTemporaryDirectory();
      final fileName = title.isNotEmpty
          ? '${title.replaceAll(RegExp(r'[^\w\s-]'), '')}.pdf'
          : 'note_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: title.isNotEmpty ? title : 'Exported Note',
      );

      // Increment export counter for free users
      if (!premiumService.isPremium) {
        await premiumService.incrementExports();
      }

      PinpointHaptics.success();

      if (mounted) {
        showSuccessToast(
          context: context,
          title: 'Exported!',
          description: 'PDF file exported successfully',
        );
      }
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
      PinpointHaptics.error();

      if (mounted) {
        showErrorToast(
          context: context,
          title: 'Export Failed',
          description: 'Unable to export PDF file',
        );
      }
    }
  }

  Future<void> _handleOcrScan(BuildContext context) async {
    // Check OCR limits
    final premiumService = PremiumService();
    if (!premiumService.canPerformOcrScan()) {
      PinpointHaptics.error();
      final remaining = premiumService.getRemainingOcrScans();
      await PremiumGateDialog.showOcrLimit(context, remaining);
      return;
    }

    try {
      // Pick an image
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Perform OCR
      final String recognizedText = await OCRService.recognizeText(image.path);

      // Close loading indicator
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (recognizedText.isEmpty) {
        PinpointHaptics.error();
        if (mounted) {
          showErrorToast(
            context: context,
            title: 'No Text Found',
            description: 'Could not detect any text in the image',
          );
        }
        return;
      }

      // Add recognized text to content
      final currentText = _contentController.text;
      final newText = currentText.isEmpty
          ? recognizedText
          : '$currentText\n\n$recognizedText';
      _contentController.text = newText;

      // Increment OCR counter
      await premiumService.incrementOcrScans();

      PinpointHaptics.success();
      if (mounted) {
        showSuccessToast(
          context: context,
          title: 'Text Extracted!',
          description: 'Text from image has been added to your note',
        );
      }
    } catch (e) {
      debugPrint('Error performing OCR: $e');
      PinpointHaptics.error();

      // Close loading indicator if still showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        showErrorToast(
          context: context,
          title: 'OCR Failed',
          description: 'Unable to scan text from image',
        );
      }
    }
  }

  void _showNoteInfoModal(BuildContext context, ColorScheme cs, bool isDark) {
    final note = widget.args?.existingNote?.note;

    if (note == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Note Info'),
          content: const Text(
              'This note hasn\'t been saved yet. Save it to see metadata.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: cs.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Text(
              'Note Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 24),

            // Metadata Items
            _buildInfoItem('Created', _formatDateTime(note.createdAt),
                Icons.event_rounded, cs),
            const SizedBox(height: 16),
            _buildInfoItem('Last Modified', _formatDateTime(note.updatedAt),
                Icons.update_rounded, cs),
            const SizedBox(height: 16),
            _buildInfoItem(
                'Note Type',
                _getLabelForNoteType(note.noteType),
                Icons.category_rounded,
                cs),
            const SizedBox(height: 16),
            _buildInfoItem('Folders', '${selectedFolders.length}',
                Icons.folder_rounded, cs),
            if (selectedNoteType == 'Todo List') ...[
              const SizedBox(height: 16),
              _buildInfoItem(
                  'Todo Items', '${todos.length}', Icons.checklist_rounded, cs),
            ],
            if (reminderDateTime != null) ...[
              const SizedBox(height: 16),
              _buildInfoItem('Reminder', _formatDateTime(reminderDateTime!),
                  Icons.alarm_rounded, cs),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
      String label, String value, IconData icon, ColorScheme cs) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: cs.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      }
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  IconData _getIconForNoteType(String noteType) {
    switch (noteType) {
      case 'Title Content':
        return Symbols.note;
      case 'Record Audio':
        return Symbols.mic;
      case 'Todo List':
        return Symbols.checklist;
      case 'Reminder':
        return Symbols.alarm;
      default:
        return Symbols.note;
    }
  }

  String _getLabelForNoteType(String noteType) {
    switch (noteType) {
      case 'Title Content':
        return 'Text Note';
      case 'Record Audio':
        return 'Voice Note';
      case 'Todo List':
        return 'Todo List';
      case 'Reminder':
        return 'Reminder';
      default:
        return 'Note';
    }
  }
}
