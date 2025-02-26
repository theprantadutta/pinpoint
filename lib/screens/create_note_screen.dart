// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
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
import '../services/drift_note_folder_service.dart';
import '../services/drift_note_service.dart';
import '../util/show_a_toast.dart';

class CreateNoteScreen extends StatefulWidget {
  static const String kRouteName = '/create-note';
  final String noticeType;
  final int? existingNoteId;

  const CreateNoteScreen({
    super.key,
    required this.noticeType,
    this.existingNoteId,
  });

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  String selectedNoteType = kNoteTypes[0];

  late QuillController _quillController;

  late TextEditingController _titleEditingController;

  List<String> selectedFolders = [DriftNoteFolderService.firstNoteFolder];

  String? audioPath;
  int? audioDuration;

  List<TodoItem> todos = [];

  late TextEditingController _reminderDescription;
  DateTime? reminderDateTime;
  List<NoteAttachmentDto> noteAttachments = [];

  setSingleSelected(List<String> value) {
    setState(() => selectedFolders = value);
  }

  @override
  void initState() {
    _quillController = QuillController.basic();
    _titleEditingController = TextEditingController(text: '');
    _reminderDescription = TextEditingController(text: '');
    selectedNoteType = widget.noticeType;
    super.initState();
  }

  @override
  void dispose() {
    _quillController.dispose();
    _titleEditingController.dispose();
    super.dispose();
  }

  Future<void> saveNoteToLocalDb() async {
    final title = _titleEditingController.text;
    final quillContent =
        jsonEncode(_quillController.document.toDelta().toJson());

    String normalizedQuillContent =
        quillContent.trim().replaceAll('\r', '').replaceAll('\n', '');
    String expected = '[{"insert":"\n"}]';

    final quillContentCheck = normalizedQuillContent == expected;
    print('quillContent check: $quillContentCheck');

    if (title.isEmpty && (quillContent.isEmpty || !quillContentCheck)) {
      showErrorToast(
        context: context,
        title: 'Failed to save Note!',
        description: 'Please Provide atleast a title or content',
      );
      return;
    }

    final now = DateTime.now();
    final noteCompanion = NotesCompanion.insert(
      title: drift.Value(title),
      isPinned: drift.Value(false),
      defaultNoteType: selectedNoteType,
      content: drift.Value(quillContent),
      audioDuration: drift.Value(audioDuration),
      audioFilePath: drift.Value(audioPath),
      reminderDescription: drift.Value(_reminderDescription.text),
      reminderTime: drift.Value(reminderDateTime),
      createdAt: now,
      updatedAt: now,
    );
    debugPrint('note: ${noteCompanion.toString()}');
    final result = await DriftNoteService.upsertANewTitleContentNote(
      noteCompanion,
      widget.existingNoteId,
    );
    if (result == false) {
      showSuccessToast(
        context: context,
        title: 'Failed to save Note!',
        description: 'Something Went Wrong when saving note',
      );
      return;
    }
    showSuccessToast(
      context: context,
      title: 'Note Saved Successfully!',
      description: 'Your note successfully saved!',
    );
    Navigator.of(context).pop();
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.81,
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
    );
  }
}
