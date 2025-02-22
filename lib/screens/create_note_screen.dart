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
import '../services/drift_note_folder_service.dart';

class CreateNoteScreen extends StatefulWidget {
  static const String kRouteName = '/create-note';
  final String noticeType;

  const CreateNoteScreen({
    super.key,
    required this.noticeType,
  });

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  String selectedNoteType = kNoteTypes[0];

  late QuillController _quillController;

  late TextEditingController _titleEditingController;

  List<String> selectedFolders = [DriftNoteFolderService.firstNoteFolder];

  setSingleSelected(List<String> value) {
    setState(() => selectedFolders = value);
  }

  @override
  void initState() {
    _quillController = QuillController.basic();
    _titleEditingController = TextEditingController(text: '');
    selectedNoteType = widget.noticeType;
    super.initState();
  }

  @override
  void dispose() {
    _quillController.dispose();
    _titleEditingController.dispose();
    super.dispose();
  }

  saveNoteToLocalDb() {
    debugPrint('title: ${_titleEditingController.text}');
    debugPrint('quill: ${_quillController.document.toDelta()}');
    debugPrint('quill: ${_quillController.document.toPlainText()}');
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
                        setState(() {
                          selectedNoteType = text;
                        });
                      },
                    ),
                    NoteInputField(
                      title: 'Title',
                      textEditingController: _titleEditingController,
                    ),
                    if (selectedNoteType == kNoteTypes[0])
                      MakeTitleContentNote(
                        quillController: _quillController,
                      ),
                    if (selectedNoteType == kNoteTypes[1]) RecordTypeContent(),
                    if (selectedNoteType == kNoteTypes[2])
                      TodoListTypeContent(),
                    if (selectedNoteType == kNoteTypes[3])
                      ReminderTypeContent(),
                  ],
                ),
              ),
              GestureDetector(
                onTap: saveNoteToLocalDb(),
                child: Container(
                  height: MediaQuery.sizeOf(context).height * 0.07,
                  width: double.infinity,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
