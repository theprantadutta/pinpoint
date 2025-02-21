import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:pinpoint/components/create_note_screen/create_note_folder_select.dart';
import 'package:pinpoint/components/create_note_screen/record_audio_type/record_type_content.dart';
import 'package:pinpoint/components/create_note_screen/todo_list_type/todo_list_type_content.dart';
import 'package:pinpoint/services/drift_note_folder_service.dart';

import '../components/create_note_screen/create_note_categories.dart';
import '../components/create_note_screen/reminder_type/reminder_type_content.dart';
import '../components/create_note_screen/title_content_type/make_title_content_note.dart';
import '../components/create_note_screen/title_content_type/note_input_field.dart';
import '../components/layouts/main_layout.dart';
import '../constants/constants.dart';

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

  late TextEditingController _titleEditingController;

  List<String> selectedFolders = [DriftNoteFolderService.firstNoteFolder];

  setSingleSelected(List<String> value) {
    setState(() => selectedFolders = value);
  }

  @override
  void initState() {
    _titleEditingController = TextEditingController(text: '');
    selectedNoteType = widget.noticeType;
    super.initState();
  }

  @override
  void dispose() {
    _titleEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      MakeTitleContentNote(),
                    if (selectedNoteType == kNoteTypes[1]) RecordTypeContent(),
                    if (selectedNoteType == kNoteTypes[2])
                      TodoListTypeContent(),
                    if (selectedNoteType == kNoteTypes[3])
                      ReminderTypeContent(),
                  ],
                ),
              ),
              Container(
                height: MediaQuery.sizeOf(context).height * 0.07,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 5,
                      spreadRadius: 2,
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
            ],
          );
        },
      ),
    );
  }
}
