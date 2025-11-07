// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../components/create_note_screen/create_note_categories.dart';
import '../components/create_note_screen/show_note_folder_bottom_sheet.dart';
import '../components/create_note_screen/show_note_tag_bottom_sheet.dart';
import '../components/create_note_screen/record_audio_type/record_type_content.dart';
import '../components/create_note_screen/reminder_type/reminder_type_content.dart';
import '../components/create_note_screen/title_content_type/make_title_content_note.dart';
import '../components/create_note_screen/todo_list_type/todo_list_type_content.dart';
import '../constants/constants.dart';
import '../database/database.dart' as db;
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

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  String selectedNoteType = kNoteTypes[0];
  late QuillController _quillController;
  late TextEditingController _titleEditingController;
  late SharePlus _sharePlus;
  List<NoteFolderDto> selectedFolders = [
    DriftNoteFolderService.firstNoteFolder
  ];
  List<db.NoteTodoItem> todos = [];
  List<db.NoteTag> selectedTags = [];
  late TextEditingController _reminderDescription;
  DateTime? reminderDateTime;
  List<NoteAttachmentDto> noteAttachments = [];
  final ScrollController _scrollController = ScrollController();
  final FocusNode _quillFocusNode = FocusNode();

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
      todos = List<db.NoteTodoItem>.from(existingNote.todoItems);
      selectedTags = List<db.NoteTag>.from(existingNote.tags);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _quillFocusNode.dispose();
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

    if (selectedNoteType == kNoteTypes[2] && todos.isEmpty) {
      _showErrorToast(
          'Failed to save Note!', 'Please add at least one todo item');
      return;
    }

    String quillContent = '';
    String quillPlainText = '';

    if (selectedNoteType == kNoteTypes[0]) {
      quillContent = jsonEncode(_quillController.document.toDelta().toJson());
      quillPlainText = _quillController.document.toPlainText().trim();
    } else if (selectedNoteType == kNoteTypes[1]) {
      quillContent = jsonEncode(_quillController.document.toDelta().toJson());
      quillPlainText = _quillController.document.toPlainText().trim();
    }

    if (_isNoteEmpty(title, quillContent) &&
        selectedNoteType != kNoteTypes[2]) {
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

    if (selectedNoteType == kNoteTypes[2]) {
      final newTodos = todos.where((todo) => todo.id < 0).toList();
      final existingTodos = todos.where((todo) => todo.id > 0).toList();

      if (widget.args?.existingNote != null) {
        for (var todo in widget.args!.existingNote!.todoItems) {
          final stillExists = todos.any((t) => t.id == todo.id);
          if (!stillExists) {
            await DriftNoteService.deleteTodoItem(todo.id);
          }
        }
      }

      for (var todo in newTodos) {
        await DriftNoteService.insertTodoItem(
          noteId: noteId,
          title: todo.todoTitle,
        );
      }

      for (var todo in existingTodos) {
        if (widget.args?.existingNote != null &&
            widget.args!.existingNote!.todoItems.any((t) => t.id == todo.id)) {
          await DriftNoteService.updateTodoItemTitle(todo.id, todo.todoTitle);
          await DriftNoteService.updateTodoItemStatus(todo.id, todo.isDone);
        } else {
          await DriftNoteService.insertTodoItem(
            noteId: noteId,
            title: todo.todoTitle,
          );
        }
      }
    }

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

    await DriftNoteService.upsertNoteTagsWithNote(
      selectedTags.map((tag) => tag.id).toList().cast<int>(),
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

  db.NotesCompanion _createNoteCompanion(
      String title, String content, String plainText, DateTime now) {
    return db.NotesCompanion.insert(
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: BackButtonListener(
        onBackButtonPressed: () async {
          final hasUnsaved = _titleEditingController.text.isNotEmpty ||
              _quillController.document.toPlainText().isNotEmpty ||
              (todos.isNotEmpty) ||
              _reminderDescription.text.isNotEmpty ||
              reminderDateTime != null;

          if (hasUnsaved) {
            final shouldSave = await ConfirmSheet.show(
              context: context,
              title: 'Unsaved Changes',
              message:
                  'You have unsaved changes. Do you want to save before leaving?',
              primaryLabel: 'Save',
              secondaryLabel: 'Discard',
              isDestructive: false,
              icon: Icons.save_rounded,
            );

            if (shouldSave == true) {
              await saveNoteToLocalDb();
              return true;
            } else if (shouldSave == false) {
              PinpointHaptics.medium();
              if (!mounted) return true;
              context.pop();
              return true;
            }
            return true;
          }
          return false;
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
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    // Title Input
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: TextField(
                          controller: _titleEditingController,
                          decoration: InputDecoration(
                            hintText: 'Note title...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            height: 1.2,
                          ),
                          maxLines: 2,
                        ),
                      ),
                    ),

                    // Note Type Selector
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: _buildNoteTypeSelector(cs, isDark),
                      ),
                    ),

                    // Content Area
                    _buildContentArea(),

                    // Metadata Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: _buildMetadataSection(cs, isDark),
                      ),
                    ),

                    // Extra padding to ensure content can scroll above keyboard and FAB
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 200,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Floating Save Button
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity,
          child: FloatingActionButton.extended(
            onPressed: () async {
              PinpointHaptics.medium();
              await saveNoteToLocalDb();
            },
            backgroundColor: cs.primary,
            elevation: 8,
            icon: Icon(
              widget.args?.existingNote != null
                  ? Symbols.save
                  : Symbols.add_circle,
              size: 24,
              color: Colors.white,
            ),
            label: Text(
              widget.args?.existingNote != null ? 'Update Note' : 'Create Note',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: cs.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back Button
          Container(
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Symbols.arrow_back, color: cs.onSurface, size: 22),
              onPressed: () {
                PinpointHaptics.light();
                Navigator.of(context).pop();
              },
            ),
          ),

          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.args?.existingNote != null ? 'Edit Note' : 'New Note',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                ),
                Text(
                  _getLabelForNoteType(selectedNoteType),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),

          // Action Buttons
          _buildActionButton(
            Symbols.share,
            () {
              PinpointHaptics.light();
              _showShareMenu(context, cs);
            },
            cs,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            Symbols.download,
            () async {
              PinpointHaptics.light();
              await _exportNote();
            },
            cs,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap, ColorScheme cs) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: cs.primary),
      ),
    );
  }

  Widget _buildNoteTypeSelector(ColorScheme cs, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: kNoteTypes.map((type) {
          final isSelected = selectedNoteType == type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                PinpointHaptics.light();
                setState(() => selectedNoteType = type);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            cs.primary,
                            cs.primary.withValues(alpha: 0.8),
                          ],
                        )
                      : null,
                  color: isSelected
                      ? null
                      : isDark
                          ? cs.surface.withValues(alpha: 0.4)
                          : cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? cs.primary.withValues(alpha: 0.3)
                        : cs.outline.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      _getIconForNoteType(type),
                      size: 18,
                      color: isSelected ? Colors.white : cs.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getLabelForNoteType(type),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : cs.onSurface,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContentArea() {
    switch (selectedNoteType) {
      case 'Title Content':
        return MakeTitleContentNote(
          quillController: _quillController,
          focusNode: _quillFocusNode,
          scrollController: _scrollController,
        );
      case 'Record Audio':
        return RecordTypeContent(
          onTranscribedText: (transcribedText) {
            if (!mounted) return;
            final currentOffset = _quillController.selection.baseOffset;
            _quillController.document.insert(currentOffset, transcribedText);
          },
        );
      case 'Todo List':
        return TodoListTypeContent(
          todos: todos,
          onTodoChanged: (newTodoItems) => setState(() => todos = newTodoItems),
        );
      case 'Reminder':
        return ReminderTypeContent(
          descriptionController: _reminderDescription,
          selectedDateTime: reminderDateTime,
          onReminderDateTimeChanged: (selectedDateTime) =>
              setState(() => reminderDateTime = selectedDateTime),
        );
      default:
        return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
  }

  Widget _buildMetadataSection(ColorScheme cs, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Folders
        _buildSectionHeader('Folders', Symbols.folder, cs),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...selectedFolders.map((folder) => _buildChip(
                  folder.title,
                  Symbols.folder,
                  cs.primary,
                  () {
                    PinpointHaptics.light();
                    // Remove folder
                    setState(() {
                      selectedFolders =
                          selectedFolders.where((f) => f != folder).toList();
                    });
                  },
                  isDark,
                )),
            _buildAddChip('Add Folder', () {
              PinpointHaptics.light();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  height: MediaQuery.of(context).size.height * 0.65,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: StreamBuilder(
                    stream: DriftNoteFolderService.watchAllNoteFoldersStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return const Center(child: Text('Something went wrong'));
                      }
                      final noteFolderData = snapshot.data ?? [];
                      return ShowNoteFolderBottomSheet(
                        selectedFolders: selectedFolders,
                        setSelectedFolders: (folders) {
                          setState(() => selectedFolders = folders);
                        },
                        noteFolderData: noteFolderData,
                      );
                    },
                  ),
                ),
              );
            }, cs, isDark),
          ],
        ),

        const SizedBox(height: 24),

        // Tags
        _buildSectionHeader('Tags', Symbols.label, cs),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...selectedTags.map((tag) => _buildChip(
                  tag.tagTitle,
                  Symbols.label,
                  cs.secondary,
                  () {
                    PinpointHaptics.light();
                    setState(() {
                      selectedTags = selectedTags.where((t) => t != tag).toList();
                    });
                  },
                  isDark,
                )),
            _buildAddChip('Add Tag', () async {
              PinpointHaptics.light();
              final allTags = await DriftNoteService.watchAllNoteTags().first;
              if (!context.mounted) return;
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  height: MediaQuery.of(context).size.height * 0.65,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: ShowNoteTagBottomSheet(
                    selectedTags: selectedTags,
                    setSelectedTags: (tags) {
                      setState(() => selectedTags = tags);
                    },
                    noteTagData: allTags,
                  ),
                ),
              );
            }, cs, isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ColorScheme cs) {
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
        ),
      ],
    );
  }

  Widget _buildChip(String label, IconData icon, Color color,
      VoidCallback onDelete, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.15)
            : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Symbols.close, size: 16, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildAddChip(String label, VoidCallback onTap, ColorScheme cs, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? cs.surface.withValues(alpha: 0.4)
              : cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outline.withValues(alpha: 0.2),
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.add, size: 14, color: cs.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareMenu(BuildContext context, ColorScheme cs) {
    final title = _titleEditingController.text.trim();
    final plainText = _quillController.document.toPlainText().trim();
    final deltaJson = _quillController.document.toDelta().toJson();
    final converter = QuillDeltaToHtmlConverter(List.castFrom(deltaJson));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: cs.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Symbols.text_fields, color: cs.primary),
                title: const Text('Share as Plain Text'),
                onTap: () {
                  PinpointHaptics.medium();
                  Navigator.pop(context);
                  _sharePlus.share(ShareParams(text: plainText, subject: title));
                },
              ),
              ListTile(
                leading: Icon(Symbols.code, color: cs.primary),
                title: const Text('Share as HTML'),
                onTap: () {
                  PinpointHaptics.medium();
                  Navigator.pop(context);
                  _sharePlus.share(
                      ShareParams(text: converter.convert(), subject: title));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportNote() async {
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

  IconData _getIconForAttachment(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.attach_file;
    }
  }
}
