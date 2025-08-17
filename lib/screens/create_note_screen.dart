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
    final quillContent =
        jsonEncode(_quillController.document.toDelta().toJson());
    final quillPlainText = _quillController.document.toPlainText().trim();

    if (_isNoteEmpty(title, quillContent)) {
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
              // await SharePlus.shareFiles([file.path], text: 'Pinpoint Note');
              _sharePlus.share(
                ShareParams(
                  // text: [file.path],
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
                  title: Text('Please Confirm!'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'You have unsaved changes. Do you wish to discard?',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(false),
                      child: const Text('No'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(true),
                      child: const Text('Yes'),
                    ),
                  ],
                );
              },
            );

            if (shouldDiscard == true) {
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
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.78,
                  child: CustomScrollView(
                    slivers: [
                      CreateNoteFolderSelect(
                        selectedFolders: selectedFolders,
                        setSelectedFolders: setSingleSelected,
                      ),
                      CreateNoteCategories(
                        selectedType: selectedNoteType,
                        onSelectedTypeChanged: (text) {
                          setState(() => selectedNoteType = text);
                        },
                      ),
                      NoteInputField(
                        title: 'Title',
                        textEditingController: _titleEditingController,
                        noteAttachments: noteAttachments,
                        onNoteAttachChanged: (value) => setState(
                          () => noteAttachments = value,
                        ),
                        onOcrCompleted: (recognizedText) {
                          final currentOffset =
                              _quillController.selection.baseOffset;
                          _quillController.document
                              .insert(currentOffset, recognizedText);
                        },
                      ),
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
                      CreateNoteTagSelect(
                        selectedTags: selectedTags,
                        onSelectedTagsChanged: (newTags) => setState(
                          () => selectedTags = newTags,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await saveNoteToLocalDb();
                  },
                  child: Container(
                    height: MediaQuery.sizeOf(context).height * 0.07,
                    width: double.infinity,
                    margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withAlpha(isDarkTheme ? 153 : 229),
                      borderRadius: AppTheme.radiusL,
                      boxShadow: [
                        BoxShadow(
                          color: kPrimaryColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        "Save Note",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
}