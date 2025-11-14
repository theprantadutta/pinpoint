import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../components/create_note_screen/create_note_categories.dart';
import '../components/create_note_screen/show_note_folder_bottom_sheet.dart';
import '../constants/constants.dart';
import '../design_system/design_system.dart';
import '../dtos/note_folder_dto.dart';
import '../services/drift_note_folder_service.dart';
import '../services/text_note_service.dart';
import '../services/voice_note_service.dart';
import '../services/todo_list_note_service.dart';
import '../services/reminder_note_service.dart';
import '../widgets/markdown_editor.dart';

/// CreateNoteScreen V2 - Architecture V8 Implementation
/// Uses new independent note type tables and type-specific services
class CreateNoteScreenV2 extends StatefulWidget {
  static const String kRouteName = '/create-note-v2';

  const CreateNoteScreenV2({super.key});

  @override
  State<CreateNoteScreenV2> createState() => _CreateNoteScreenV2State();
}

class _CreateNoteScreenV2State extends State<CreateNoteScreenV2> {
  // Note type selection
  String selectedNoteType = kNoteTypes[0]; // Default to 'Title Content'

  // Common fields
  late TextEditingController _titleController;
  late FocusNode _titleFocusNode;
  List<NoteFolderDto> selectedFolders = [];

  // Text note fields
  late TextEditingController _textContentController;
  late FocusNode _textContentFocusNode;

  // Voice note fields
  String? _audioFilePath;
  int? _audioDurationSeconds;
  String? _audioTranscription;

  // Todo list fields
  final List<String> _todoItems = [];

  // Reminder fields
  DateTime? _reminderTime;
  late TextEditingController _reminderDescriptionController;

  // Save tracking
  int? _currentNoteId; // Track saved note ID
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _titleFocusNode = FocusNode();
    _textContentController = TextEditingController();
    _textContentFocusNode = FocusNode();
    _reminderDescriptionController = TextEditingController();

    // Initialize folders
    _initializeFolders();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    _textContentController.dispose();
    _textContentFocusNode.dispose();
    _reminderDescriptionController.dispose();
    super.dispose();
  }

  /// Initialize folders - ensure "Random" folder exists
  Future<void> _initializeFolders() async {
    try {
      // Get existing folders
      final folders = await DriftNoteFolderService.watchAllNoteFoldersStream().first;

      if (folders.isNotEmpty && mounted) {
        setState(() {
          // Default to first folder (usually "Random")
          selectedFolders = [
            NoteFolderDto(
              id: folders.first.noteFolderId,
              title: folders.first.noteFolderTitle,
            )
          ];
        });
      }
    } catch (e) {
      debugPrint('❌ [CreateNoteV2] Failed to initialize folders: $e');
      // Keep empty folders list if initialization fails
    }
  }

  /// Show folder selection bottom sheet
  Future<void> _showFolderBottomSheet() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allFolders = await DriftNoteFolderService.watchAllNoteFoldersStream().first;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ShowNoteFolderBottomSheet(
          selectedFolders: selectedFolders,
          setSelectedFolders: (folders) {
            if (mounted) {
              setState(() {
                selectedFolders = folders;
              });
            }
          },
          noteFolderData: allFolders,
        ),
      ),
    );
  }

  /// Save note based on current type
  Future<void> _saveNote() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final title = _titleController.text.trim().isEmpty
          ? 'Untitled'
          : _titleController.text.trim();

      // Ensure folders are selected
      if (selectedFolders.isEmpty) {
        await _initializeFolders();
        if (selectedFolders.isEmpty) {
          throw Exception('No folders available');
        }
      }

      int noteId;

      switch (selectedNoteType) {
        case 'Title Content':
          noteId = await _saveTextNote(title);
          break;

        case 'Record Audio':
          noteId = await _saveVoiceNote(title);
          break;

        case 'Todo List':
          noteId = await _saveTodoListNote(title);
          break;

        case 'Reminder':
          noteId = await _saveReminderNote(title);
          break;

        default:
          throw Exception('Unknown note type: $selectedNoteType');
      }

      _currentNoteId = noteId;
      debugPrint('✅ [CreateNoteV2] Note saved successfully: $_currentNoteId');
    } catch (e, st) {
      debugPrint('❌ [CreateNoteV2] Failed to save note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<int> _saveTextNote(String title) async {
    final content = _textContentController.text;
    return await TextNoteService.createTextNote(
      title: title,
      content: content,
      folders: selectedFolders,
    );
  }

  Future<int> _saveVoiceNote(String title) async {
    // TODO: Implement voice note saving
    // For now, create a placeholder
    return await VoiceNoteService.createVoiceNote(
      title: title,
      audioFilePath: _audioFilePath ?? '',
      folders: selectedFolders,
      durationSeconds: _audioDurationSeconds,
      transcription: _audioTranscription,
    );
  }

  Future<int> _saveTodoListNote(String title) async {
    return await TodoListNoteService.createTodoListNote(
      title: title,
      folders: selectedFolders,
      initialItems: _todoItems.where((item) => item.isNotEmpty).toList(),
    );
  }

  Future<int> _saveReminderNote(String title) async {
    if (_reminderTime == null) {
      throw Exception('Reminder time is required');
    }

    return await ReminderNoteService.createReminderNote(
      title: title,
      reminderTime: _reminderTime!,
      folders: selectedFolders,
      description: _reminderDescriptionController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            _buildHeader(context, cs, isDark),

            // Content
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  // Folder Selection
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: _buildFolderSection(cs, isDark),
                    ),
                  ),

                  // Type Selector
                  CreateNoteCategories(
                    selectedType: selectedNoteType,
                    onSelectedTypeChanged: (type) {
                      setState(() {
                        selectedNoteType = type;
                      });
                    },
                  ),

                  // Dynamic Content Area
                  _buildContentArea(),
                ],
              ),
            ),
          ],
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
            onPressed: () async {
              PinpointHaptics.light();

              // Save before exiting
              if (_shouldSave()) {
                await _saveNote();
              }

              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          ),

          // Title Input
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
                focusNode: _titleFocusNode,
                decoration: InputDecoration(
                  hintText: 'Untitled',
                  border: InputBorder.none,
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
                ),
                maxLines: 1,
                textInputAction: TextInputAction.done,
              ),
            ),
          ),

          // Save button
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Icon(Symbols.check, color: cs.primary),
              iconSize: 24,
              onPressed: () async {
                PinpointHaptics.light();
                await _saveNote();
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFolderSection(ColorScheme cs, bool isDark) {
    return GestureDetector(
      onTap: () async {
        await _showFolderBottomSheet();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Symbols.folder,
              size: 20,
              color: cs.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedFolders.isEmpty
                    ? 'Select folders'
                    : selectedFolders.map((f) => f.title).join(', '),
                style: TextStyle(
                  color: selectedFolders.isEmpty
                      ? cs.onSurface.withValues(alpha: 0.5)
                      : cs.onSurface,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Symbols.chevron_right,
              size: 20,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentArea() {
    switch (selectedNoteType) {
      case 'Title Content':
        return _buildTextNoteContent();
      case 'Record Audio':
        return _buildVoiceNoteContent();
      case 'Todo List':
        return _buildTodoListContent();
      case 'Reminder':
        return _buildReminderContent();
      default:
        return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
  }

  Widget _buildTextNoteContent() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: MarkdownEditor(
          controller: _textContentController,
          focusNode: _textContentFocusNode,
          hintText: 'Write your note in markdown...',
          showToolbar: true,
          enablePreview: true,
        ),
      ),
    );
  }

  Widget _buildVoiceNoteContent() {
    // TODO: Implement voice note UI
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Voice note UI coming soon',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodoListContent() {
    // TODO: Implement todo list UI
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Todo list UI coming soon',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReminderContent() {
    // TODO: Implement reminder UI
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Reminder UI coming soon',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  /// Check if note should be saved
  bool _shouldSave() {
    final hasTitle = _titleController.text.trim().isNotEmpty;
    final hasContent = _textContentController.text.trim().isNotEmpty;
    final hasTodos = _todoItems.any((item) => item.isNotEmpty);
    final hasReminder = _reminderTime != null;

    return hasTitle || hasContent || hasTodos || hasReminder;
  }
}
