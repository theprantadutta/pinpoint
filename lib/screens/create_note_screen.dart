// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';

import '../components/create_note_screen/create_note_categories.dart';
import '../components/create_note_screen/create_note_folder_select.dart';
import '../components/create_note_screen/record_audio_type/record_type_content.dart';
import '../components/create_note_screen/reminder_type/reminder_type_content.dart';
import '../components/create_note_screen/title_content_type/make_title_content_note.dart';
import '../components/create_note_screen/title_content_type/note_input_field.dart';
import '../components/create_note_screen/todo_list_type/todo_list_type_content.dart';
import '../components/create_note_screen/create_note_tag_select.dart';
import '../components/layouts/main_layout.dart';
import '../constants/constants.dart';
import '../database/database.dart';
import '../dtos/note_attachment_dto.dart';
import '../dtos/note_folder_dto.dart';
import '../services/drift_note_folder_service.dart';
import '../services/drift_note_service.dart';
import '../util/show_a_toast.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:share_plus/share_plus.dart';
import '../services/logger_service.dart';
import 'package:pinpoint/design/app_theme.dart';

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

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  String selectedNoteType = kNoteTypes[0];

  late QuillController _quillController;

  late TextEditingController _titleEditingController;

  late SharePlus _sharePlus;

  List<NoteFolderDto> selectedFolders = [
    DriftNoteFolderService.firstNoteFolder
  ];

  List<NoteTodoItem> todos = [];
  List<NoteTag> selectedTags = [];

  late TextEditingController _reminderDescription;
  DateTime? reminderDateTime;
  List<NoteAttachmentDto> noteAttachments = [];

  void setSingleSelected(List<NoteFolderDto> value) {
    setState(() => selectedFolders = value);
  }

  @override
  void initState() {
    super.initState();
    _quillController = QuillController.basic();
    _titleEditingController = TextEditingController(text: '');
    _reminderDescription = TextEditingController(text: '');
    _sharePlus = SharePlus.instance;
    if (widget.args?.existingNote != null) {
      final existingNote = widget.args!.existingNote!;
      selectedNoteType = existingNote.note.defaultNoteType;
      _titleEditingController.text = existingNote.note.noteTitle ?? '';
      try {
        final raw = existingNote.note.content ?? '';
        final decoded = raw.isNotEmpty ? jsonDecode(raw) : null;
        _quillController.document =
            decoded != null ? Document.fromJson(decoded) : Document();
      } catch (e, st) {
        log.w('[CreateNote] Failed to parse existing note content', e, st);
        _quillController.document = Document();
      }
      selectedFolders = existingNote.folders;
      todos = List<NoteTodoItem>.from(existingNote.todoItems);
      selectedTags = List<NoteTag>.from(existingNote.tags);
    }
  }

  @override
  void dispose() {
    try {
      _quillController.dispose();
    } catch (_) {}
    try {
      _titleEditingController.dispose();
    } catch (_) {}
    try {
      _reminderDescription.dispose();
    } catch (_) {}
    super.dispose();
  }

  Future<void> saveNoteToLocalDb() async {
    final title = _titleEditingController.text.trim();
    
    // Validate todo notes
    if (selectedNoteType == kNoteTypes[2] && todos.isEmpty) {
      _showErrorToast(
          'Failed to save Note!', 'Please add at least one todo item');
      return;
    }
    
    // Validate other note types
    String quillContent = '';
    String quillPlainText = '';
    
    if (selectedNoteType == kNoteTypes[0]) {
      quillContent = jsonEncode(_quillController.document.toDelta().toJson());
      quillPlainText = _quillController.document.toPlainText().trim();
    } else if (selectedNoteType == kNoteTypes[1]) {
      // For audio notes, we'll save the transcription if available
      quillContent = jsonEncode(_quillController.document.toDelta().toJson());
      quillPlainText = _quillController.document.toPlainText().trim();
    }

    // For todo notes, we don't require content since the todos are the content
    if (_isNoteEmpty(title, quillContent) && selectedNoteType != kNoteTypes[2]) {
      _showErrorToast(
          'Failed to save Note!', 'Please provide at least a title or content');
      return;
    }

    final now = DateTime.now();
    final noteCompanion =
        _createNoteCompanion(title, quillContent, quillPlainText, now);
    final noteId = await DriftNoteService.upsertANewTitleContentNote(
        noteCompanion, widget.args?.existingNote?.note.id);

    if (noteId == 0) {
      _showErrorToast(
          'Failed to save Note!', 'Something went wrong while saving the note');
      return;
    }

    // Handle todo items for todo list notes
    if (selectedNoteType == kNoteTypes[2]) {
      // Separate new todos (negative IDs) from existing ones
      final newTodos = todos.where((todo) => todo.id < 0).toList();
      final existingTodos = todos.where((todo) => todo.id > 0).toList();
      
      // Delete all existing todos for this note first (to handle deletions)
      if (widget.args?.existingNote != null) {
        for (var todo in widget.args!.existingNote!.todoItems) {
          // Check if this todo still exists in our current list
          final stillExists = todos.any((t) => t.id == todo.id);
          if (!stillExists) {
            await DriftNoteService.deleteTodoItem(todo.id);
          }
        }
      }
      
      // Insert new todos
      for (var todo in newTodos) {
        await DriftNoteService.insertTodoItem(
          noteId: noteId,
          title: todo.todoTitle,
        );
      }
      
      // Handle existing todos
      for (var todo in existingTodos) {
        // Check if this is an existing todo from the same note
        if (widget.args?.existingNote != null && 
            widget.args!.existingNote!.todoItems.any((t) => t.id == todo.id)) {
          // Update the existing todo
          await DriftNoteService.updateTodoItemTitle(todo.id, todo.todoTitle);
          await DriftNoteService.updateTodoItemStatus(todo.id, todo.isDone);
        } else {
          // This is a new todo, insert it
          await DriftNoteService.insertTodoItem(
            noteId: noteId,
            title: todo.todoTitle,
          );
        }
      }
    }

    // Add Folders
    final result = await DriftNoteFolderService.upsertNoteFoldersWithNote(
      selectedFolders,
      noteId,
    );

    if (!result) {
      _showErrorToast(
          'Failed to save folders!', 'Some folders may not have been saved.');
    }

    final attachmentsUpdated =
        await DriftNoteService.upsertNoteAttachments(noteAttachments, noteId);
    if (!attachmentsUpdated) {
      _showErrorToast('Failed to save Attachments!',
          'Some attachments may not have been saved.');
    }

    // Add Tags
    await DriftNoteService.upsertNoteTagsWithNote(
      selectedTags.map((tag) => tag.id).toList(),
      noteId,
    );

    _showSuccessToast(
        'Note Saved Successfully!', 'Your note was successfully saved!');
    Navigator.of(context).pop();
  }

  bool _isNoteEmpty(String title, String quillContent) {
    const String emptyQuillContent = '[{"insert":"\n"}]';
    return title.isEmpty &&
        (quillContent.isEmpty ||
            quillContent.trim().replaceAll('\r', '').replaceAll('\n', '') ==
                emptyQuillContent);
  }

  NotesCompanion _createNoteCompanion(
      String title, String content, String plainText, DateTime now) {
    return NotesCompanion.insert(
      noteTitle: drift.Value(title),
      isPinned: drift.Value(false),
      defaultNoteType: selectedNoteType,
      content: drift.Value(content),
      contentPlainText: drift.Value(plainText),
      reminderDescription: drift.Value(_reminderDescription.text),
      reminderTime: drift.Value(reminderDateTime),
      createdAt: now,
      updatedAt: now,
    );
  }

  void _showErrorToast(String title, String description) {
    showErrorToast(context: context, title: title, description: description);
  }

  void _showSuccessToast(String title, String description) {
    showSuccessToast(context: context, title: title, description: description);
  }

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final darkerColor =
        isDarkTheme ? Colors.grey.shade400 : Colors.grey.shade600;
        
    return MainLayout(
      actions: [
        IconButton(
          icon: Icon(
            Symbols.share,
            size: 20,
            color: darkerColor,
          ),
          onPressed: () {
            final title = _titleEditingController.text.trim();
            final plainText = _quillController.document.toPlainText().trim();
            final deltaJson = _quillController.document.toDelta().toJson();
            final converter = QuillDeltaToHtmlConverter(
              List.castFrom(deltaJson),
            );

            showModalBottomSheet(
              context: context,
              builder: (context) {
                return Glass(
                  padding: const EdgeInsets.all(16.0),
                  child: Wrap(
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.text_fields),
                        title: const Text('Share as Plain Text'),
                        onTap: () {
                          Navigator.pop(context);
                          _sharePlus.share(
                              ShareParams(text: plainText, subject: title));
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.html),
                        title: const Text('Share as HTML'),
                        onTap: () {
                          Navigator.pop(context);
                          _sharePlus.share(ShareParams(
                              text: converter.convert(), subject: title));
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.picture_as_pdf),
                        title: const Text('Share as PDF'),
                        onTap: () async {},
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(width: 10),
        Icon(
          Symbols.keep_rounded,
          size: 20,
          color: darkerColor,
        ),
        const SizedBox(width: 10),
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'export') {
              final noteJson = {
                'title': _titleEditingController.text.trim(),
                'content': _quillController.document.toDelta().toJson(),
                'folders': selectedFolders.map((e) => e.title).toList(),
                'tags': selectedTags.map((e) => e.tagTitle).toList(),
                'attachments': noteAttachments.map((e) => e.path).toList(),
              };
              final jsonString = jsonEncode(noteJson);
              final tempDir = await getTemporaryDirectory();
              final file = await File(
                      '${tempDir.path}/${_titleEditingController.text.trim()}.pinpoint-note')
                  .writeAsString(jsonString);
              _sharePlus.share(
                ShareParams(
                  files: [XFile(file.path)],
                  subject: 'Pinpoint Note',
                ),
              );
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'export',
              child: Text('Export'),
            ),
          ],
          icon: Icon(
            Symbols.more_vert_rounded,
            size: 20,
            color: darkerColor,
          ),
        ),
      ],
      body: BackButtonListener(
        onBackButtonPressed: () async {
          final hasUnsaved = _titleEditingController.text.isNotEmpty ||
              _quillController.document.toPlainText().isNotEmpty ||
              (todos.isNotEmpty) ||
              _reminderDescription.text.isNotEmpty ||
              reminderDateTime != null;

          if (hasUnsaved) {
            final shouldDiscard = await showDialog<bool>(
              context: context,
              builder: (dialogCtx) {
                return AlertDialog(
                  title: const Text('Unsaved Changes'),
                  content: const Text(
                    'You have unsaved changes. Do you want to save before leaving?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(false),
                      child: const Text('Discard'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.of(dialogCtx).pop(true);
                        await saveNoteToLocalDb();
                      },
                      child: const Text('Save'),
                    ),
                  ],
                );
              },
            );

            if (shouldDiscard == true) {
              // Save was handled in the dialog
              return true;
            } else if (shouldDiscard == false) {
              // Discard changes
              if (!mounted) return true;
              context.pop();
              return true;
            }
            return true; // consumed back press
          }
          return false; // allow default pop
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                // Header with note type indicator
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        kPrimaryColor.withAlpha(20),
                        kPrimaryColor.withAlpha(10),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getIconForNoteType(selectedNoteType),
                        color: kPrimaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.args?.existingNote != null 
                              ? 'Edit Note' 
                              : 'New Note',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: kPrimaryColor,
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: kPrimaryColor.withAlpha(50),
                          ),
                        ),
                        child: Text(
                          _getLabelForNoteType(selectedNoteType),
                          style: TextStyle(
                            color: kPrimaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Main content area
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      // Title input
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          child: Glass(
                            padding: const EdgeInsets.all(16),
                            child: TextField(
                              controller: _titleEditingController,
                              decoration: const InputDecoration(
                                hintText: 'Note title',
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Note type selector
                      CreateNoteCategories(
                        selectedType: selectedNoteType,
                        onSelectedTypeChanged: (text) {
                          setState(() => selectedNoteType = text);
                        },
                      ),
                      
                      // Content based on note type
                      if (selectedNoteType == kNoteTypes[0])
                        MakeTitleContentNote(
                          quillController: _quillController,
                        ),
                      if (selectedNoteType == kNoteTypes[1])
                        RecordTypeContent(
                          onTranscribedText: (transcribedText) {
                            if (!mounted) return;
                            final currentOffset =
                                _quillController.selection.baseOffset;
                            _quillController.document
                                .insert(currentOffset, transcribedText);
                          },
                        ),
                      if (selectedNoteType == kNoteTypes[2])
                        TodoListTypeContent(
                          todos: todos,
                          onTodoChanged: (newTodoItems) => setState(
                            () => todos = newTodoItems,
                          ),
                        ),
                      if (selectedNoteType == kNoteTypes[3])
                        ReminderTypeContent(
                          descriptionController: _reminderDescription,
                          selectedDateTime: reminderDateTime,
                          onReminderDateTimeChanged: (selectedDateTime) =>
                              setState(
                            () => reminderDateTime = selectedDateTime,
                          ),
                        ),
                      
                      // Folder selection
                      CreateNoteFolderSelect(
                        selectedFolders: selectedFolders,
                        setSelectedFolders: setSingleSelected,
                      ),
                      
                      // Tag selection
                      CreateNoteTagSelect(
                        selectedTags: selectedTags,
                        onSelectedTagsChanged: (newTags) => setState(
                          () => selectedTags = newTags,
                        ),
                      ),
                      
                      // Attachments
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Attachments',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              if (noteAttachments.isNotEmpty)
                                SizedBox(
                                  height: 100,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: noteAttachments.length,
                                    itemBuilder: (context, index) {
                                      final attachment = noteAttachments[index];
                                      return Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        width: 80,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Theme.of(context).colorScheme.outline,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _getIconForAttachment(attachment.path),
                                              size: 24,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              attachment.path.split('/').last,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 10),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () {
                                  // TODO: Implement attachment functionality
                                },
                                icon: const Icon(Icons.attach_file),
                                label: const Text('Add Attachment'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Spacing at bottom
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 20),
                      ),
                    ],
                  ),
                ),
                
                // Save button
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Glass(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: () async {
                        await saveNoteToLocalDb();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.radiusL,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.args?.existingNote != null 
                                ? Icons.save 
                                : Icons.add,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.args?.existingNote != null 
                                ? 'Update Note' 
                                : 'Create Note',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
  
  IconData _getIconForNoteType(String noteType) {
    switch (noteType) {
      case 'title_content':
        return Icons.note;
      case 'record':
        return Icons.mic;
      case 'todo':
        return Icons.checklist;
      case 'reminder':
        return Icons.alarm;
      default:
        return Icons.note;
    }
  }
  
  String _getLabelForNoteType(String noteType) {
    switch (noteType) {
      case 'title_content':
        return 'Text Note';
      case 'record':
        return 'Voice Note';
      case 'todo':
        return 'Todo List';
      case 'reminder':
        return 'Reminder';
      default:
        return 'Note';
    }
  }
  
  IconData _getIconForAttachment(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'mp3':
      case 'wav':
      case 'm4a':
        return Icons.audiotrack;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.videocam;
      default:
        return Icons.insert_drive_file;
    }
  }
}