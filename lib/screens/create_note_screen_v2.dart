import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image_picker/image_picker.dart';
import 'package:fleather/fleather.dart';

import '../components/create_note_screen/create_note_categories.dart';
import '../components/create_note_screen/reminder_type/reminder_type_content.dart';
import '../components/create_note_screen/show_note_folder_bottom_sheet.dart';
import '../constants/constants.dart';
import '../database/database.dart';
import '../design_system/design_system.dart';
import '../dtos/note_folder_dto.dart';
import '../screen_arguments/create_note_screen_arguments.dart';
import '../constants/premium_limits.dart';
import '../services/drift_note_folder_service.dart';
import '../services/text_note_service.dart';
import '../services/voice_note_service.dart';
import '../services/todo_list_note_service.dart';
import '../services/reminder_note_service.dart';
import '../services/premium_service.dart';
import '../services/ocr_service.dart';
import '../util/show_a_toast.dart';
import '../widgets/markdown_editor.dart';
import '../widgets/premium_gate_dialog.dart';
import '../widgets/usage_stats_bottom_sheet.dart';

/// CreateNoteScreen V2 - Architecture V8 Implementation
/// Uses new independent note type tables and type-specific services
class CreateNoteScreenV2 extends StatefulWidget {
  static const String kRouteName = '/create-note-v2';
  final CreateNoteScreenArguments? arguments;

  const CreateNoteScreenV2({super.key, this.arguments});

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
  late FleatherController _fleatherController;
  late FocusNode _textContentFocusNode;

  // Voice note fields
  String? _audioFilePath;
  int? _audioDurationSeconds;
  String? _audioTranscription;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  Timer? _recordingTimer;
  Duration _recordedDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  // Todo list fields
  List<TodoItemEntity> _todoItems = [];
  String? _todoListNoteUuid;

  // Reminder fields
  DateTime? _reminderTime;
  late TextEditingController _reminderNotificationTitleController;
  late TextEditingController _reminderNotificationContentController;
  late TextEditingController _reminderDescriptionController; // Deprecated, but kept for backward compatibility

  // Recurrence fields
  String _recurrenceType = 'once'; // once, hourly, daily, weekly, monthly, yearly
  int _recurrenceInterval = 1;
  String _recurrenceEndType = 'never'; // never, after_occurrences, on_date
  String? _recurrenceEndValue;

  // Save tracking
  int? _currentNoteId; // Track saved note ID
  bool _isSaving = false;
  Timer? _autoSaveTimer; // Auto-save timer

  @override
  void initState() {
    super.initState();

    // Set initial note type from arguments if provided
    if (widget.arguments?.noticeType != null) {
      selectedNoteType = widget.arguments!.noticeType;
    }

    _titleController = TextEditingController();
    _titleFocusNode = FocusNode();
    _fleatherController = FleatherController();
    _textContentFocusNode = FocusNode();
    _reminderNotificationTitleController = TextEditingController();
    _reminderNotificationContentController = TextEditingController();
    _reminderDescriptionController = TextEditingController(); // Deprecated

    // Add auto-save listeners
    _titleController.addListener(_scheduleAutoSave);
    _fleatherController.addListener(_scheduleAutoSave);
    _reminderNotificationTitleController.addListener(_scheduleAutoSave);
    _reminderNotificationContentController.addListener(_scheduleAutoSave);
    _reminderDescriptionController.addListener(_scheduleAutoSave);

    // Add audio player listeners for playback tracking
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _playbackPosition = position;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _playbackDuration = duration;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playbackPosition = Duration.zero;
        });
      }
    });

    // Initialize folders
    _initializeFolders();

    // Load existing note if editing
    if (widget.arguments?.existingNote != null) {
      _loadExistingNote();
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _titleFocusNode.dispose();
    _fleatherController.dispose();
    _textContentFocusNode.dispose();
    _reminderNotificationTitleController.dispose();
    _reminderNotificationContentController.dispose();
    _reminderDescriptionController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Initialize folders - ensure "Random" folder exists
  Future<void> _initializeFolders() async {
    try {
      // Get existing folders
      final folders =
          await DriftNoteFolderService.watchAllNoteFoldersStream().first;

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

  /// Load existing note for editing
  Future<void> _loadExistingNote() async {
    try {
      final existingNote = widget.arguments!.existingNote!;
      final note = existingNote.note;

      // Set note ID and basic info
      _currentNoteId = note.id;
      _titleController.text = note.noteTitle ?? '';

      // Set folders
      selectedFolders = existingNote.folders
          .map((f) => NoteFolderDto(id: f.id, title: f.title))
          .toList();

      // Load type-specific content based on note type
      if (note.noteType == 'text') {
        // Text note
        selectedNoteType = 'Title Content';
        // Load raw content from database (not the plain text version)
        final textNote = await TextNoteService.getTextNote(note.id);
        if (textNote != null && textNote.content.isNotEmpty) {
          _fleatherController = MarkdownEditor.createControllerFromMarkdown(
              textNote.content);
        }
      } else if (note.noteType == 'voice') {
        // Voice note
        selectedNoteType = 'Record Audio';
        final voiceNote = await VoiceNoteService.getVoiceNote(note.id);
        if (voiceNote != null) {
          _audioFilePath = voiceNote.audioFilePath;
          _audioDurationSeconds = voiceNote.durationSeconds ?? 0;
          _audioTranscription = voiceNote.transcription;
        }
      } else if (note.noteType == 'todo') {
        // Todo note
        selectedNoteType = 'Todo List';
        final todoNote = await TodoListNoteService.getTodoListNote(note.id);
        if (todoNote != null) {
          _todoListNoteUuid = todoNote.uuid;
          // Load todo items
          final items = await TodoListNoteService.watchTodoItems(note.id).first;
          _todoItems = items;
        }
      } else if (note.noteType == 'reminder') {
        // Reminder note
        selectedNoteType = 'Reminder';
        final reminderNote = await ReminderNoteService.getReminderNote(note.id);
        if (reminderNote != null) {
          _reminderTime = reminderNote.reminderTime;
          _reminderNotificationTitleController.text = reminderNote.notificationTitle ?? reminderNote.title ?? '';
          _reminderNotificationContentController.text = reminderNote.notificationContent ?? '';
          _reminderDescriptionController.text = reminderNote.description ?? ''; // Deprecated, but kept for backward compatibility
          _recurrenceType = reminderNote.recurrenceType ?? 'once';
          _recurrenceInterval = reminderNote.recurrenceInterval ?? 1;
          _recurrenceEndType = reminderNote.recurrenceEndType ?? 'never';
          _recurrenceEndValue = reminderNote.recurrenceEndValue;
        }
      }

      if (mounted) {
        setState(() {});
      }

      debugPrint('✅ [CreateNoteV2] Loaded existing note: ${note.id}');
    } catch (e, st) {
      debugPrint('❌ [CreateNoteV2] Failed to load existing note: $e');
      debugPrint('Stack trace: $st');
    }
  }

  /// Show folder selection bottom sheet
  Future<void> _showFolderBottomSheet() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allFolders =
        await DriftNoteFolderService.watchAllNoteFoldersStream().first;

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
      final title = _titleController.text.trim();

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
    final content = MarkdownEditor.controllerToMarkdown(_fleatherController);

    if (_currentNoteId != null) {
      // Update existing note
      await TextNoteService.updateTextNote(
        noteId: _currentNoteId!,
        title: title,
        content: content,
        folders: selectedFolders,
      );
      return _currentNoteId!;
    } else {
      // Create new note
      return await TextNoteService.createTextNote(
        title: title,
        content: content,
        folders: selectedFolders,
      );
    }
  }

  Future<int> _saveVoiceNote(String title) async {
    if (_currentNoteId != null) {
      // Update existing note
      await VoiceNoteService.updateVoiceNote(
        noteId: _currentNoteId!,
        title: title,
        audioFilePath: _audioFilePath,
        folders: selectedFolders,
        durationSeconds: _audioDurationSeconds,
        transcription: _audioTranscription,
      );
      return _currentNoteId!;
    } else {
      // Create new note
      return await VoiceNoteService.createVoiceNote(
        title: title,
        audioFilePath: _audioFilePath ?? '',
        folders: selectedFolders,
        durationSeconds: _audioDurationSeconds,
        transcription: _audioTranscription,
      );
    }
  }

  Future<int> _saveTodoListNote(String title) async {
    if (_currentNoteId != null) {
      // Update existing note
      await TodoListNoteService.updateTodoListNote(
        noteId: _currentNoteId!,
        title: title,
        folders: selectedFolders,
      );
      return _currentNoteId!;
    } else {
      // Create new note with actual todo items (convert to string content)
      final initialItemTexts = _todoItems.map((item) => item.content).toList();
      final noteId = await TodoListNoteService.createTodoListNote(
        title: title,
        folders: selectedFolders,
        initialItems: initialItemTexts.isNotEmpty ? initialItemTexts : null,
      );

      // Get the note UUID for adding items
      final todoNote = await TodoListNoteService.getTodoListNote(noteId);
      if (todoNote != null) {
        _todoListNoteUuid = todoNote.uuid;
      }

      return noteId;
    }
  }

  Future<int> _saveReminderNote(String title) async {
    if (_reminderTime == null) {
      throw Exception('Reminder time is required');
    }

    // Validate that reminder time is in the future
    if (_reminderTime!.isBefore(DateTime.now())) {
      throw Exception('Reminder time must be in the future');
    }

    // Use notification title if provided, otherwise fall back to note title
    final notificationTitle = _reminderNotificationTitleController.text.isNotEmpty
        ? _reminderNotificationTitleController.text
        : title;

    if (_currentNoteId != null) {
      // Update existing note
      await ReminderNoteService.updateReminderNote(
        noteId: _currentNoteId!,
        title: title,
        notificationTitle: notificationTitle,
        notificationContent: _reminderNotificationContentController.text.isNotEmpty
            ? _reminderNotificationContentController.text
            : null,
        reminderTime: _reminderTime,
        folders: selectedFolders,
        recurrenceType: _recurrenceType,
        recurrenceInterval: _recurrenceInterval,
        recurrenceEndType: _recurrenceEndType,
        recurrenceEndValue: _recurrenceEndValue,
      );
      return _currentNoteId!;
    } else {
      // Create new note(s) - may create multiple for recurring reminders
      final noteIds = await ReminderNoteService.createReminderNote(
        title: title,
        notificationTitle: notificationTitle,
        notificationContent: _reminderNotificationContentController.text.isNotEmpty
            ? _reminderNotificationContentController.text
            : null,
        reminderTime: _reminderTime!,
        folders: selectedFolders,
        recurrenceType: _recurrenceType,
        recurrenceInterval: _recurrenceInterval,
        recurrenceEndType: _recurrenceEndType,
        recurrenceEndValue: _recurrenceEndValue,
      );

      // Return the first note ID (parent/primary reminder)
      return noteIds.first;
    }
  }

  /// Schedule auto-save with 2 second debounce
  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _autoSaveNote();
      }
    });
  }

  /// Auto-save note based on content
  Future<void> _autoSaveNote() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();

    // Check if there's any content to save based on note type
    bool hasContent = false;

    switch (selectedNoteType) {
      case 'Title Content':
        final content =
            MarkdownEditor.controllerToMarkdown(_fleatherController).trim();
        hasContent = title.isNotEmpty || content.isNotEmpty;
        break;

      case 'Record Audio':
        hasContent = _audioFilePath != null;
        break;

      case 'Todo List':
        hasContent = title.isNotEmpty || _todoItems.isNotEmpty;
        break;

      case 'Reminder':
        hasContent = _reminderTime != null;
        break;
    }

    if (!hasContent) {
      debugPrint('⏭️ [CreateNoteV2] Auto-save skipped: No content');
      return;
    }

    debugPrint(
        '💾 [CreateNoteV2] Auto-saving note (type: $selectedNoteType)...');

    try {
      await _saveNote();
      debugPrint('✅ [CreateNoteV2] Auto-save completed');
    } catch (e) {
      debugPrint('⚠️ [CreateNoteV2] Auto-save failed: $e');
      // Don't show error to user for auto-save failures
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            _buildHeader(context, cs, isDark),

            // Content
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  // Note Type Selection
                  CreateNoteCategories(
                    selectedType: selectedNoteType,
                    onSelectedTypeChanged: (type) {
                      PinpointHaptics.light();
                      setState(() => selectedNoteType = type);
                    },
                  ),

                  // Folder Selection
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showFolderBottomSheet(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? cs.surfaceContainerHighest
                                    .withValues(alpha: 0.3)
                                : cs.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cs.outline.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: selectedFolders.isEmpty
                              ? Row(
                                  children: [
                                    Icon(
                                      Symbols.add,
                                      size: 18,
                                      color: cs.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Add to folder',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color:
                                            cs.onSurface.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color:
                                          cs.onSurface.withValues(alpha: 0.4),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Icon(
                                      Symbols.folder,
                                      size: 18,
                                      color: cs.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: selectedFolders.map((folder) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: cs.primary
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: cs.primary
                                                    .withValues(alpha: 0.15),
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Text(
                                              folder.title,
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                color: cs.primary
                                                    .withValues(alpha: 0.9),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.edit_rounded,
                                      size: 16,
                                      color:
                                          cs.onSurface.withValues(alpha: 0.4),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
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
          IconButton(
            icon: Icon(Symbols.arrow_back, color: cs.onSurface),
            iconSize: 24,
            onPressed: () async {
              PinpointHaptics.light();

              // Cancel auto-save timer to prevent conflicts
              _autoSaveTimer?.cancel();

              // Save before exiting (but don't trigger sync to avoid db locks)
              if (_shouldSave()) {
                try {
                  await _saveNote();
                  // Give a brief moment for save to complete
                  await Future.delayed(const Duration(milliseconds: 100));
                } catch (e) {
                  debugPrint('⚠️ [CreateNoteV2] Error saving on back: $e');
                  // Continue navigation even if save fails
                }
              }

              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          ),

          const SizedBox(width: 5),

          // Title Input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                decoration: InputDecoration(
                  hintText: 'Untitled',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  isDense: true,
                  hintStyle: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w500,
                    fontSize: 20,
                  ),
                ),
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
                maxLines: 1,
                textInputAction: TextInputAction.done,
              ),
            ),
          ),

          const SizedBox(width: 5),

          // Three-dot menu
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: cs.onSurface),
            iconSize: 24,
            padding: EdgeInsets.zero,
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) async {
              PinpointHaptics.light();
              switch (value) {
                case 'save':
                  await _saveNote();
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                  break;
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
                case 'usage':
                  _showUsageStats(context);
                  break;
                case 'info':
                  _showNoteInfo(context, cs, isDark);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Symbols.check, size: 20, color: cs.primary),
                    const SizedBox(width: 12),
                    const Text('Save & Close'),
                  ],
                ),
              ),
              if (_currentNoteId != null) ...[
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
              ],
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
              if (selectedNoteType == 'Title Content')
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
                          final total =
                              PremiumLimits.maxOcrScansPerMonthForFree;

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
              if (selectedNoteType == 'Title Content')
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
                              horizontal: 6, vertical: 2),
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
              if (selectedNoteType == 'Title Content')
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
                              horizontal: 6, vertical: 2),
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
                    Text('Share Encrypted',
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.4))),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
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
              // Usage Stats
              PopupMenuItem(
                value: 'usage',
                child: Row(
                  children: [
                    Icon(Icons.analytics_outlined, size: 20, color: cs.primary),
                    const SizedBox(width: 12),
                    const Text('Usage'),
                  ],
                ),
              ),
              if (_currentNoteId != null)
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
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return SliverToBoxAdapter(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7 - keyboardHeight,
        child: MarkdownEditor(
          controller: _fleatherController,
          focusNode: _textContentFocusNode,
          hintText: 'Start writing your note...',
          showToolbar: true,
          onChanged: (markdown) {
            // Content changes are automatically saved via transaction stream
          },
        ),
      ),
    );
  }

  Widget _buildVoiceNoteContent() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            // Recording UI (shown when recording or no audio exists)
            if (_audioFilePath == null || _isRecording) ...[
              // Recording indicator / status
              if (_isRecording) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                        : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: cs.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Recording...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatDuration(_recordedDuration),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // Record button
              GestureDetector(
                onTap: _isRecording ? _stopRecording : _startRecording,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _isRecording
                          ? [cs.error, cs.error.withValues(alpha: 0.8)]
                          : [cs.primary, cs.primary.withValues(alpha: 0.8)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording ? cs.error : cs.primary)
                            .withValues(alpha: 0.3),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Symbols.stop : Symbols.mic,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Status text
              Text(
                _isRecording
                    ? 'Tap to stop recording'
                    : 'Tap to start recording',
                style: TextStyle(
                  fontSize: 15,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],

            // Audio player UI (shown when audio exists and not recording)
            if (_audioFilePath != null && !_isRecording) ...[
              // Audio player card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primaryContainer.withValues(alpha: 0.5),
                      cs.secondaryContainer.withValues(alpha: 0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: cs.outline.withValues(alpha: 0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Audio icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primary.withValues(alpha: 0.1),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Symbols.audio_file,
                        size: 40,
                        color: cs.primary,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Progress slider
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        activeTrackColor: cs.primary,
                        inactiveTrackColor: cs.primary.withValues(alpha: 0.2),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                        thumbColor: cs.primary,
                        overlayColor: cs.primary.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _playbackPosition.inMilliseconds.toDouble(),
                        max: _playbackDuration.inMilliseconds > 0
                            ? _playbackDuration.inMilliseconds.toDouble()
                            : (_audioDurationSeconds != null
                                ? (_audioDurationSeconds! * 1000).toDouble()
                                : 100.0),
                        onChanged: (value) async {
                          final position = Duration(milliseconds: value.toInt());
                          await _audioPlayer.seek(position);
                        },
                      ),
                    ),

                    // Time display
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_playbackPosition),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface.withValues(alpha: 0.7),
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(
                            _formatDuration(_playbackDuration.inMilliseconds > 0
                                ? _playbackDuration
                                : Duration(seconds: _audioDurationSeconds ?? 0)),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface.withValues(alpha: 0.7),
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Playback controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Play/Pause button
                        IconButton.filled(
                          onPressed: _isPlaying ? _pausePlayback : _startPlayback,
                          icon: Icon(_isPlaying ? Symbols.pause : Symbols.play_arrow),
                          iconSize: 32,
                          style: IconButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(20),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Stop button
                        IconButton.outlined(
                          onPressed: _stopPlayback,
                          icon: const Icon(Symbols.stop),
                          iconSize: 28,
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(18),
                            side: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Replace recording button
              OutlinedButton.icon(
                onPressed: _replaceRecording,
                icon: const Icon(Symbols.refresh),
                label: const Text('Record Again'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  side: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
                  foregroundColor: cs.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTodoListContent() {
    final cs = Theme.of(context).colorScheme;

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == _todoItems.length) {
              // Add new todo button
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: _addTodoItem,
                  icon: Icon(Symbols.add, size: 20),
                  label: const Text('Add Todo Item'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    side: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                  ),
                ),
              );
            }

            final item = _todoItems[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Checkbox (interactive)
                    Checkbox(
                      value: item.isCompleted,
                      onChanged: (value) async {
                        if (value != null) {
                          await _toggleTodoItem(item.id);
                        }
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Todo text (also interactive - tapping toggles completion)
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await _toggleTodoItem(item.id);
                        },
                        child: Text(
                          item.content,
                          style: TextStyle(
                            fontSize: 15,
                            color: cs.onSurface,
                            decoration: item.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ),
                    // Delete button
                    IconButton(
                      icon: Icon(
                        Symbols.delete_outline,
                        size: 20,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                      onPressed: () async {
                        await _deleteTodoItem(item.id);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: _todoItems.length + 1, // +1 for add button
        ),
      ),
    );
  }

  Future<void> _toggleTodoItem(int itemId) async {
    try {
      await TodoListNoteService.toggleTodoItemCompletion(itemId);
      // Reload items from database
      if (_currentNoteId != null) {
        final items =
            await TodoListNoteService.watchTodoItems(_currentNoteId!).first;
        if (mounted) {
          setState(() {
            _todoItems = items;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to toggle todo item: $e');
    }
  }

  Future<void> _deleteTodoItem(int itemId) async {
    try {
      await TodoListNoteService.deleteTodoItem(itemId);
      // Reload items from database
      if (_currentNoteId != null) {
        final items =
            await TodoListNoteService.watchTodoItems(_currentNoteId!).first;
        if (mounted) {
          setState(() {
            _todoItems = items;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to delete todo item: $e');
    }
  }

  Future<void> _addTodoItem() async {
    // Ensure we have a note created first
    if (_currentNoteId == null) {
      await _saveNote();
      if (_currentNoteId == null) {
        debugPrint('❌ Failed to create todo list note');
        return;
      }
    }

    if (!mounted) return;

    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Todo Item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter todo item',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) async {
            if (value.trim().isNotEmpty) {
              await _saveTodoItemToDatabase(value.trim());
              if (mounted) {
                Navigator.pop(context);
              }
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await _saveTodoItemToDatabase(controller.text.trim());
                if (mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTodoItemToDatabase(String content) async {
    try {
      if (_currentNoteId == null || _todoListNoteUuid == null) {
        debugPrint('❌ Cannot add todo item: note not created yet');
        return;
      }

      await TodoListNoteService.addTodoItem(
        todoListNoteId: _currentNoteId!,
        todoListNoteUuid: _todoListNoteUuid!,
        content: content,
      );

      // Reload items from database
      final items =
          await TodoListNoteService.watchTodoItems(_currentNoteId!).first;
      if (mounted) {
        setState(() {
          _todoItems = items;
        });
      }

      debugPrint('✅ Added todo item: $content');
    } catch (e) {
      debugPrint('❌ Failed to add todo item: $e');
    }
  }

  Widget _buildReminderContent() {
    // ReminderTypeContent already returns a SliverToBoxAdapter
    return ReminderTypeContent(
      notificationTitleController: _reminderNotificationTitleController,
      notificationContentController: _reminderNotificationContentController,
      selectedDateTime: _reminderTime,
      recurrenceType: _recurrenceType,
      recurrenceInterval: _recurrenceInterval,
      recurrenceEndType: _recurrenceEndType,
      recurrenceEndValue: _recurrenceEndValue,
      onReminderDateTimeChanged: (DateTime selectedDateTime) {
        setState(() {
          _reminderTime = selectedDateTime;
        });
      },
      onRecurrenceTypeChanged: (String type) {
        setState(() {
          _recurrenceType = type;
        });
      },
      onRecurrenceIntervalChanged: (int interval) {
        setState(() {
          _recurrenceInterval = interval;
        });
      },
      onRecurrenceEndTypeChanged: (String type) {
        setState(() {
          _recurrenceEndType = type;
        });
      },
      onRecurrenceEndValueChanged: (String? value) {
        setState(() {
          _recurrenceEndValue = value;
        });
      },
    );
  }

  Future<void> _pickReminderDateTime() async {
    DateTime now = DateTime.now();
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && mounted) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _reminderTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
        _scheduleAutoSave();
      }
    }
  }

  String _formatReminderDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (date == today) {
      dateStr = 'Today';
    } else if (date == tomorrow) {
      dateStr = 'Tomorrow';
    } else {
      // Format as "Mon, Jan 1, 2025"
      final months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      dateStr =
          '${weekdays[dateTime.weekday]}, ${months[dateTime.month]} ${dateTime.day}, ${dateTime.year}';
    }

    // Format time as 12-hour format
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '$dateStr at $hour:$minute $period';
  }

  /// Check if note should be saved
  bool _shouldSave() {
    final hasTitle = _titleController.text.trim().isNotEmpty;
    // Check plain text content, not JSON - empty Fleather editor is just "\n"
    final plainText = MarkdownEditor.getPlainText(_fleatherController).trim();
    final hasContent = plainText.isNotEmpty;
    final hasTodos = _todoItems.isNotEmpty;
    final hasReminder = _reminderTime != null;
    final hasAudio = _audioFilePath != null;

    return hasTitle || hasContent || hasTodos || hasReminder || hasAudio;
  }

  // Voice Note Recording Methods

  Future<void> _startRecording() async {
    try {
      // Check and request permission
      if (!await _audioRecorder.hasPermission()) {
        debugPrint('❌ [VoiceNote] No microphone permission');
        return;
      }

      // Get temporary directory for audio file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final audioPath = '${tempDir.path}/voice_note_$timestamp.m4a';

      // Start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: audioPath,
      );

      setState(() {
        _isRecording = true;
        _recordedDuration = Duration.zero;
      });

      // Start timer to update duration
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordedDuration =
                Duration(seconds: _recordedDuration.inSeconds + 1);
          });
        }
      });

      debugPrint('🎤 [VoiceNote] Started recording to: $audioPath');
    } catch (e) {
      debugPrint('❌ [VoiceNote] Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _recordingTimer?.cancel();

      if (path != null && mounted) {
        setState(() {
          _audioFilePath = path;
          _audioDurationSeconds = _recordedDuration.inSeconds;
          _isRecording = false;
        });
        _scheduleAutoSave();
        debugPrint(
            '✅ [VoiceNote] Stopped recording. Duration: $_audioDurationSeconds seconds');
        debugPrint('📁 [VoiceNote] Audio saved to: $path');
      }
    } catch (e) {
      debugPrint('❌ [VoiceNote] Failed to stop recording: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _startPlayback() async {
    if (_audioFilePath == null) return;

    try {
      await _audioPlayer.play(DeviceFileSource(_audioFilePath!));
      setState(() {
        _isPlaying = true;
      });

      // Listen for playback completion
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
      });

      debugPrint('▶️ [VoiceNote] Started playback');
    } catch (e) {
      debugPrint('❌ [VoiceNote] Failed to start playback: $e');
    }
  }

  Future<void> _pausePlayback() async {
    try {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
      debugPrint('⏸️ [VoiceNote] Paused playback');
    } catch (e) {
      debugPrint('❌ [VoiceNote] Failed to pause playback: $e');
    }
  }

  Future<void> _stopPlayback() async {
    try {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
        _playbackPosition = Duration.zero;
      });
      debugPrint('⏹️ [VoiceNote] Stopped playback');
    } catch (e) {
      debugPrint('❌ [VoiceNote] Failed to stop playback: $e');
    }
  }

  Future<void> _replaceRecording() async {
    try {
      // Stop any ongoing playback
      if (_isPlaying) {
        await _stopPlayback();
      }

      // Delete old audio file if it exists
      if (_audioFilePath != null) {
        try {
          final file = File(_audioFilePath!);
          if (await file.exists()) {
            await file.delete();
            debugPrint('🗑️ [VoiceNote] Deleted old audio file: $_audioFilePath');
          }
        } catch (e) {
          debugPrint('⚠️ [VoiceNote] Failed to delete old audio file: $e');
          // Continue anyway - we'll overwrite the path
        }
      }

      // Clear audio state
      setState(() {
        _audioFilePath = null;
        _audioDurationSeconds = null;
        _recordedDuration = Duration.zero;
        _playbackPosition = Duration.zero;
        _playbackDuration = Duration.zero;
        _isPlaying = false;
      });

      // Trigger auto-save to update the note (remove audio)
      _scheduleAutoSave();

      debugPrint('🔄 [VoiceNote] Ready to record again');
    } catch (e) {
      debugPrint('❌ [VoiceNote] Failed to replace recording: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// Handle delete note
  void _handleDeleteNote(BuildContext context, ColorScheme cs) {
    if (_currentNoteId == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Close the dialog first
              Navigator.pop(dialogContext);

              // Delete based on note type
              switch (selectedNoteType) {
                case 'Title Content':
                  await TextNoteService.deleteTextNote(_currentNoteId!);
                  break;
                case 'Record Audio':
                  await VoiceNoteService.deleteVoiceNote(_currentNoteId!);
                  break;
                case 'Todo List':
                  await TodoListNoteService.deleteTodoListNote(_currentNoteId!);
                  break;
                case 'Reminder':
                  await ReminderNoteService.deleteReminderNote(_currentNoteId!);
                  break;
              }

              // Navigate back to previous screen using screen context, not dialog context
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text('Delete', style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
  }

  /// Show note info modal
  void _showNoteInfo(BuildContext context, ColorScheme cs, bool isDark) {
    if (_currentNoteId == null) return;

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
              'Note Info',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 24),
            _buildInfoRow('Type', selectedNoteType, cs),
            const SizedBox(height: 12),
            _buildInfoRow('ID', _currentNoteId.toString(), cs),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Folder',
              selectedFolders.isEmpty ? 'None' : selectedFolders.first.title,
              cs,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Handle share note
  Future<void> _handleShareNote(BuildContext context) async {
    final title = _titleController.text.trim();
    String content = '';

    // Get content based on note type
    switch (selectedNoteType) {
      case 'Title Content':
        content =
            MarkdownEditor.controllerToMarkdown(_fleatherController).trim();
        break;
      case 'Todo List':
        content = _todoItems
            .map((item) => '${item.isCompleted ? '✓' : '○'} ${item.content}')
            .join('\n');
        break;
      case 'Reminder':
        content = _reminderDescriptionController.text.trim();
        if (_reminderTime != null) {
          content += '\nReminder: ${_reminderTime.toString()}';
        }
        break;
      default:
        content = '';
    }

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

    Share.share(
      '$title\n\n$content',
      subject: title,
    );

    PinpointHaptics.success();
  }

  /// Handle export markdown
  Future<void> _handleExportMarkdown(BuildContext context) async {
    if (selectedNoteType != 'Title Content') return;

    final title = _titleController.text.trim();
    final content =
        MarkdownEditor.controllerToMarkdown(_fleatherController).trim();

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
      final markdown = StringBuffer();

      if (title.isNotEmpty) {
        markdown.writeln('# $title');
        markdown.writeln();
      }

      if (content.isNotEmpty) {
        markdown.writeln(content);
      }

      markdown.writeln();
      markdown.writeln('---');
      markdown.writeln('*Exported from Pinpoint*');
      markdown.writeln('*Date: ${DateTime.now().toString().split('.')[0]}*');

      final directory = await getTemporaryDirectory();
      final fileName = title.isNotEmpty
          ? '${title.replaceAll(RegExp(r'[^\w\s-]'), '')}.md'
          : 'note_${DateTime.now().millisecondsSinceEpoch}.md';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(markdown.toString());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: title.isNotEmpty ? title : 'Exported Note',
      );

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

  /// Handle export PDF
  Future<void> _handleExportPdf(BuildContext context) async {
    if (selectedNoteType != 'Title Content') return;

    final title = _titleController.text.trim();
    final content =
        MarkdownEditor.controllerToMarkdown(_fleatherController).trim();

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
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
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

      final directory = await getTemporaryDirectory();
      final fileName = title.isNotEmpty
          ? '${title.replaceAll(RegExp(r'[^\w\s-]'), '')}.pdf'
          : 'note_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: title.isNotEmpty ? title : 'Exported Note',
      );

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

  /// Handle OCR scan
  Future<void> _handleOcrScan(BuildContext context) async {
    if (selectedNoteType != 'Title Content') return;

    final premiumService = PremiumService();
    if (!premiumService.canPerformOcrScan()) {
      PinpointHaptics.error();
      final remaining = premiumService.getRemainingOcrScans();
      await PremiumGateDialog.showOcrLimit(context, remaining);
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final String recognizedText = await OCRService.recognizeText(image.path);

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

      final currentText =
          MarkdownEditor.controllerToMarkdown(_fleatherController);
      final newText = currentText.isEmpty
          ? recognizedText
          : '$currentText\n\n$recognizedText';
      _fleatherController =
          MarkdownEditor.createControllerFromMarkdown(newText);

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

  /// Show usage stats
  void _showUsageStats(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const UsageStatsBottomSheet(),
    );
  }
}
