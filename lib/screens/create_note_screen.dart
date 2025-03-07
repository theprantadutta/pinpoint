// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../components/create_note_screen/create_note_categories.dart';
import '../components/create_note_screen/create_note_folder_select.dart';
import '../components/create_note_screen/record_audio_type/record_type_content.dart';
import '../components/create_note_screen/reminder_type/reminder_type_content.dart';
import '../components/create_note_screen/title_content_type/make_title_content_note.dart';
import '../components/create_note_screen/title_content_type/note_input_field.dart';
import '../components/create_note_screen/todo_list_type/todo_list_type_content.dart';
import '../components/layouts/main_layout.dart';
import '../constants/constants.dart';
import '../database/database.dart';
import '../dtos/note_attachment_dto.dart';
import '../dtos/note_folder_dto.dart';
import '../services/drift_note_folder_service.dart';
import '../services/drift_note_service.dart';
import '../util/show_a_toast.dart';

class CreateNoteScreen extends StatefulWidget {
  static const String kRouteName = '/create-note';
  final Note? existingNote;
  final List<NoteAttachment> noteAttachments;
  final String noticeType;

  const CreateNoteScreen({
    super.key,
    this.existingNote,
    this.noteAttachments = const [],
    required this.noticeType,
  });

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  String selectedNoteType = kNoteTypes[0];

  late QuillController _quillController;

  late TextEditingController _titleEditingController;

  List<NoteFolderDto> selectedFolders = [
    DriftNoteFolderService.firstNoteFolder
  ];

  String? audioPath;
  int? audioDuration;

  List<TodoItem> todos = [];

  late TextEditingController _reminderDescription;
  DateTime? reminderDateTime;
  List<NoteAttachmentDto> noteAttachments = [];

  setSingleSelected(List<NoteFolderDto> value) {
    setState(() => selectedFolders = value);
  }

  @override
  void initState() {
    _quillController = QuillController.basic();
    _titleEditingController = TextEditingController(text: '');
    _reminderDescription = TextEditingController(text: '');
    if (widget.existingNote != null) {
      final existingNote = widget.existingNote!;
      selectedNoteType = existingNote.defaultNoteType;
      _titleEditingController.text = existingNote.title ?? '';
      _quillController.document =
          Document.fromJson(jsonDecode(existingNote.content ?? ''));
      // selectedFolders = existingNote.
    }
    super.initState();
  }

  @override
  void dispose() {
    _quillController.dispose();
    _titleEditingController.dispose();
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
        noteCompanion, widget.existingNote?.id);

    if (noteId == 0) {
      _showErrorToast(
          'Failed to save Note!', 'Something went wrong while saving the note');
      return;
    }

    final attachmentsUpdated =
        await DriftNoteService.upsertNoteAttachments(noteAttachments, noteId);
    if (!attachmentsUpdated) {
      _showErrorToast('Failed to save Attachments!',
          'Some attachments may not have been saved.');
    }

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
      title: drift.Value(title),
      isPinned: drift.Value(false),
      defaultNoteType: selectedNoteType,
      content: drift.Value(content),
      contentPlainText: drift.Value(plainText),
      audioDuration: drift.Value(audioDuration),
      audioFilePath: drift.Value(audioPath),
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
        Icon(
          Symbols.keep_rounded,
          size: 20,
          color: darkerColor,
        ),
        SizedBox(width: 10),
        Icon(
          Symbols.more_vert_rounded,
          size: 20,
          color: darkerColor,
        ),
      ],
      body: BackButtonListener(
        onBackButtonPressed: () async {
          if (_titleEditingController.text.isNotEmpty ||
              _quillController.document.toPlainText().isNotEmpty ||
              (audioPath != null && audioPath!.isNotEmpty) ||
              (todos.isNotEmpty) ||
              _reminderDescription.text.isNotEmpty ||
              reminderDateTime != null) {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text('Please Confirm!'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'You have unsaved changes. Do you wish to discard?',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('No'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context
                            .pop(); // Ensure GoRouter is handling navigation properly
                      },
                      child: Text('Yes'),
                    ),
                  ],
                );
              },
            );
            return true;
          }
          return false;
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.8,
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
                      ),
                      if (selectedNoteType == kNoteTypes[0])
                        MakeTitleContentNote(
                          quillController: _quillController,
                        ),
                      if (selectedNoteType == kNoteTypes[1])
                        RecordTypeContent(
                          audioPath: audioPath,
                          onAudioPathChanged: (audioPathValue) =>
                              audioPath = audioPathValue,
                          audioDuration: audioDuration,
                          onAudioDurationChanged: (audioDurationValue) =>
                              setState(
                            () => audioDuration == audioDurationValue,
                          ),
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
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: saveNoteToLocalDb,
                  child: Container(
                    height: MediaQuery.sizeOf(context).height * 0.07,
                    width: double.infinity,
                    margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withValues(
                          alpha: isDarkTheme ? 0.6 : 0.9),
                      borderRadius: BorderRadius.circular(12),
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
