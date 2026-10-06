import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fleather/fleather.dart';

import '../service_locators/init_service_locators.dart';
import '../services/audio_upload_queue.dart';
import '../services/analytics/analytics_facade.dart';
import '../components/create_note_screen/editor_chrome.dart';
import '../components/create_note_screen/editor_overflow_menu.dart';
import '../components/create_note_screen/note_export_actions.dart';
import '../components/create_note_screen/record_audio_type/voice_fab.dart';
import '../components/create_note_screen/record_audio_type/voice_note_body.dart';
import '../components/create_note_screen/reminder_type/reminder_type_content.dart';
import '../components/create_note_screen/show_note_folder_bottom_sheet.dart';
import '../components/create_note_screen/title_content_type/ocr_scan_card.dart';
import '../components/create_note_screen/todo_list_type/checklist_add_bar.dart';
import '../components/create_note_screen/todo_list_type/checklist_editor.dart';
import '../constants/constants.dart';
import '../database/database.dart';
import '../design_system/design_system.dart';
import '../design_system/components/note_color_picker.dart';
import '../services/drift_note_service.dart';
import '../dtos/note_folder_dto.dart';
import '../screen_arguments/create_note_screen_arguments.dart';
import '../constants/premium_limits.dart';
import '../services/drift_note_folder_service.dart';
import '../services/text_note_service.dart';
import '../services/voice_note_service.dart';
import '../services/voice_recording_files.dart';
import '../services/todo_list_note_service.dart';
import '../services/reminder_note_service.dart';
import '../services/premium_service.dart';
import '../services/ocr_service.dart';
import '../util/folder_palette.dart';
import '../util/show_a_toast.dart';
import '../widgets/markdown_editor.dart';
import '../widgets/markdown_toolbar.dart';
import '../widgets/premium_gate_dialog.dart';
import '../widgets/usage_stats_bottom_sheet.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

/// CreateNoteScreen V2 - Architecture V8 Implementation
/// Uses new independent note type tables and type-specific services
///
/// Sketchbook layout (SCREENS.md §04/§05): a top bar (back, folder chip, pin,
/// ⋯), a 28/800 title, an "Edited · Encrypted" meta row, then the body for
/// the note type — the rich-text editor with the floating [MarkdownToolbar]
/// and voice button, the checklist with its add bar, the voice recorder, or
/// the reminder form. The pieces live in `lib/components/create_note_screen/`;
/// this State owns the data, saving, recording and quotas.
class CreateNoteScreenV2 extends StatefulWidget {
  static const String kRouteName = '/create-note-v2';
  final CreateNoteScreenArguments? arguments;

  /// When true, the editor is hosted inside a master–detail pane (tablet/iPad)
  /// instead of pushed as a full-screen route. In this mode the exit actions
  /// (back, save & close, delete) invoke [onClose] to clear the pane selection
  /// rather than popping the enclosing page.
  final bool embedded;

  /// Called in place of `Navigator.pop` when [embedded] is true.
  final VoidCallback? onClose;

  const CreateNoteScreenV2({
    super.key,
    this.arguments,
    this.embedded = false,
    this.onClose,
  });

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
  late final Stream<List<NoteFolder>> _foldersStream =
      DriftNoteFolderService.watchFolders();

  // Text note fields
  late FleatherController _fleatherController;
  late FocusNode _textContentFocusNode;

  // OCR: the picked image waiting for "Extract text" (never stored).
  String? _ocrImagePath;
  bool _ocrBusy = false;

  // Voice note fields
  String? _audioFilePath;
  bool _audioTooLargeForCloud = false;
  int? _audioDurationSeconds;
  String? _audioTranscription;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  // True once a source has been loaded into _audioPlayer. Seeking before a
  // source is set throws "Bad state: No element" inside audioplayers.
  bool _hasAudioSource = false;
  Timer? _recordingTimer;
  Duration _recordedDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  // Todo list fields
  List<TodoItemEntity> _todoItems = [];
  String? _todoListNoteUuid;
  final FocusNode _addTaskFocusNode = FocusNode();

  // Keep-style note color (swatch name); null = default card color.
  String? _selectedColor;

  // Keep-style note attributes.
  bool _isPinned = false;
  bool _isArchived = false;

  // Reminder fields
  DateTime? _reminderTime;
  late TextEditingController _reminderNotificationTitleController;
  late TextEditingController _reminderNotificationContentController;
  late TextEditingController
      _reminderDescriptionController; // Deprecated, but kept for backward compatibility

  // Recurrence fields
  String _recurrenceType =
      'once'; // once, hourly, daily, weekly, monthly, yearly
  int _recurrenceInterval = 1;
  String _recurrenceEndType = 'never'; // never, after_occurrences, on_date
  String? _recurrenceEndValue;

  // Save tracking
  int? _currentNoteId; // Track saved note ID
  bool _isSaving = false;
  Timer? _autoSaveTimer; // Auto-save timer
  DateTime? _editedAt; // "Edited {date}"

  /// Title + body of the text note as last loaded or saved. The editor
  /// notifies on every cursor move, so auto-save compares against this
  /// rather than re-saving (and re-dating) an unchanged note.
  String? _savedTextSignature;

  String _textSignature() =>
      '${_titleController.text.trim()}\n${MarkdownEditor.controllerToMarkdown(_fleatherController)}';

  /// Drives the checklist's "Auto-saved" / "Saving…" chip. Held true for at
  /// least [_savingMinVisible] so a fast local write still reads as a flash.
  final ValueNotifier<bool> _saving = ValueNotifier(false);
  DateTime? _savingSince;
  Timer? _savingOffTimer;
  static const Duration _savingMinVisible = Duration(milliseconds: 600);

  bool get _isText => selectedNoteType == 'Title Content';
  bool get _isTodo => selectedNoteType == 'Todo List';
  bool get _isVoice => selectedNoteType == 'Record Audio';
  bool get _isReminder => selectedNoteType == 'Reminder';

  @override
  void initState() {
    super.initState();
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'CreateNote');

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
    } else if (widget.arguments?.autoStartRecording == true && _isVoice) {
      // Opened from the text editor's microphone: record straight away.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startRecording();
      });
    }
  }

  /// Leave the editor: when embedded in a detail pane, clear the selection via
  /// [CreateNoteScreenV2.onClose]; otherwise pop the full-screen route.
  void _exitEditor(BuildContext context) {
    if (widget.embedded) {
      widget.onClose?.call();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _savingOffTimer?.cancel();
    _saving.dispose();
    _titleController.dispose();
    _titleFocusNode.dispose();
    _fleatherController.dispose();
    _textContentFocusNode.dispose();
    _addTaskFocusNode.dispose();
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

      // An existing note's own folders win over the default.
      if (folders.isNotEmpty && mounted && selectedFolders.isEmpty) {
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
      _selectedColor = existingNote.color;
      _isPinned = note.isPinned;
      _isArchived = note.isArchived;
      _editedAt = note.updatedAt;

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
          _fleatherController.removeListener(_scheduleAutoSave);
          _fleatherController =
              MarkdownEditor.createControllerFromMarkdown(textNote.content);
          _fleatherController.addListener(_scheduleAutoSave);
        }
      } else if (note.noteType == 'voice') {
        // Voice note
        selectedNoteType = 'Record Audio';
        final voiceNote = await VoiceNoteService.getVoiceNote(note.id);
        if (voiceNote != null) {
          _audioFilePath = voiceNote.audioFilePath;
          _audioTooLargeForCloud =
              await AudioUploadQueue.tooLargeForCloud(voiceNote.audioFilePath);
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
          _reminderNotificationTitleController.text =
              reminderNote.notificationTitle ?? reminderNote.title ?? '';
          _reminderNotificationContentController.text =
              reminderNote.notificationContent ?? '';
          _reminderDescriptionController.text = reminderNote.description ??
              ''; // Deprecated, but kept for backward compatibility
          _recurrenceType = reminderNote.recurrenceType;
          _recurrenceInterval = reminderNote.recurrenceInterval;
          _recurrenceEndType = reminderNote.recurrenceEndType;
          _recurrenceEndValue = reminderNote.recurrenceEndValue;
        }
      }

      // Loading set the fields; that is not an edit worth an auto-save.
      _autoSaveTimer?.cancel();
      if (selectedNoteType == 'Title Content') {
        _savedTextSignature = _textSignature();
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
    await ShowNoteFolderBottomSheet.show(
      context,
      selected: selectedFolders,
      onChanged: (folders) {
        if (mounted) {
          setState(() {
            selectedFolders = folders;
          });
          // Folder membership is part of the note: save it right away.
          if (_currentNoteId != null && !_isReminder) {
            unawaited(_saveNote().catchError((Object e) {
              debugPrint('⚠️ [CreateNoteV2] Saving folders failed: $e');
            }));
          }
        }
      },
    );
  }

  void _setSaving(bool saving) {
    if (saving) {
      _savingOffTimer?.cancel();
      _savingSince = DateTime.now();
      _saving.value = true;
      return;
    }
    final shown = DateTime.now().difference(_savingSince ?? DateTime.now());
    final remaining = _savingMinVisible - shown;
    _savingOffTimer?.cancel();
    if (remaining > Duration.zero) {
      _savingOffTimer = Timer(remaining, () {
        if (mounted) _saving.value = false;
      });
    } else if (mounted) {
      _saving.value = false;
    }
  }

  /// Runs a direct database write (checklist items) under the saving chip.
  Future<T> _withSaving<T>(Future<T> Function() write) async {
    _setSaving(true);
    try {
      final result = await write();
      if (mounted) setState(() => _editedAt = DateTime.now());
      return result;
    } finally {
      _setSaving(false);
    }
  }

  /// Save note based on current type.
  /// [isExplicit] distinguishes user-initiated saves from auto-saves for analytics.
  Future<void> _saveNote({bool isExplicit = false}) async {
    // Serialize saves: if a save (e.g. the 2-second auto-save) is already
    // running, wait for it to finish instead of bailing out. Bailing out is
    // what made a quick "paste then back" sometimes drop the latest title or
    // body — the explicit back-save would no-op because an auto-save was
    // mid-flight. Waiting guarantees the newest content is persisted.
    while (_isSaving) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _isSaving = true;
    _setSaving(true);

    try {
      final title = _titleController.text.trim();
      final isNew = _currentNoteId == null;

      // Ensure folders are selected
      if (selectedFolders.isEmpty) {
        await _initializeFolders();
        if (selectedFolders.isEmpty) {
          // No folders at all: never lose the note over it.
          final fallback = await DriftNoteFolderService.ensureDefaultFolder();
          if (mounted) setState(() => selectedFolders = [fallback]);
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

      // Track analytics: always track creates, only track explicit updates
      final analytics = getIt<AnalyticsFacade>();
      final noteTypeKey = _noteTypeToKey(selectedNoteType);

      // Persist the Keep-style note attributes (color, pin, archive).
      await DriftNoteService.setNoteColor(noteId, noteTypeKey, _selectedColor);
      await DriftNoteService.setNotePinned(noteId, noteTypeKey, _isPinned);
      await DriftNoteService.setNoteArchived(noteId, noteTypeKey, _isArchived);
      if (isNew) {
        analytics.trackNoteCreated(noteType: noteTypeKey);
      } else if (isExplicit) {
        analytics.trackNoteUpdated(noteType: noteTypeKey);
      }

      if (mounted) setState(() => _editedAt = DateTime.now());

      debugPrint('✅ [CreateNoteV2] Note saved successfully: $_currentNoteId');
    } catch (e, st) {
      debugPrint('❌ [CreateNoteV2] Failed to save note: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    } finally {
      // Always release the lock (no setState needed — build doesn't read it).
      _isSaving = false;
      _setSaving(false);
    }
  }

  String _noteTypeToKey(String noteType) {
    switch (noteType) {
      case 'Title Content':
        return 'text';
      case 'Record Audio':
        return 'voice';
      case 'Todo List':
        return 'todo';
      case 'Reminder':
        return 'reminder';
      default:
        return noteType.toLowerCase();
    }
  }

  Future<int> _saveTextNote(String title) async {
    final content = MarkdownEditor.controllerToMarkdown(_fleatherController);
    final int noteId;

    if (_currentNoteId != null) {
      // Update existing note
      await TextNoteService.updateTextNote(
        noteId: _currentNoteId!,
        title: title,
        content: content,
        folders: selectedFolders,
      );
      noteId = _currentNoteId!;
    } else {
      // Create new note
      noteId = await TextNoteService.createTextNote(
        title: title,
        content: content,
        folders: selectedFolders,
      );
    }
    _savedTextSignature = '$title\n$content';
    return noteId;
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
    final notificationTitle =
        _reminderNotificationTitleController.text.isNotEmpty
            ? _reminderNotificationTitleController.text
            : title;

    if (_currentNoteId != null) {
      // Update existing note
      await ReminderNoteService.updateReminderNote(
        noteId: _currentNoteId!,
        title: title,
        notificationTitle: notificationTitle,
        notificationContent:
            _reminderNotificationContentController.text.isNotEmpty
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
        notificationContent:
            _reminderNotificationContentController.text.isNotEmpty
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

    // Skip auto-save for reminders - they require explicit save due to backend API calls
    // and must have a valid future time
    if (selectedNoteType == 'Reminder') {
      debugPrint(
          '⏭️ [CreateNoteV2] Auto-save skipped: Reminders require explicit save');
      return;
    }

    final title = _titleController.text.trim();

    // Check if there's any content to save based on note type
    bool hasContent = false;

    switch (selectedNoteType) {
      case 'Title Content':
        final content =
            MarkdownEditor.controllerToMarkdown(_fleatherController).trim();
        hasContent = (title.isNotEmpty || content.isNotEmpty) &&
            _textSignature() != _savedTextSignature;
        break;

      case 'Record Audio':
        hasContent = _audioFilePath != null;
        break;

      case 'Todo List':
        hasContent = title.isNotEmpty || _todoItems.isNotEmpty;
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

  // ============================================
  // Build
  // ============================================

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    // Read above the Scaffold: inside its resizing body the keyboard inset
    // has already been consumed.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final noteColor = NoteSwatch.resolve(_selectedColor)?.color;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    final showVoiceFab = !keyboardOpen &&
        ((_isText) || (_isVoice && (_audioFilePath == null || _isRecording)));

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: s.bg,
      body: DoodleBackground(
        top: _isText ? DoodleBackground.editorTop : DoodleBackground.todoTop,
        squiggle: _isText,
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: SketchContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: CustomScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        slivers: [
                          _buildTitleSliver(),
                          ..._buildContentSlivers(),
                        ],
                      ),
                    ),
                    if (_isReminder)
                      SketchBottomCta(
                        button: PillButton(
                          label: AppL10n.of(context).edSaveReminder,
                          onPressed: () => _saveAndClose(context),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Note colour: a 6px pastel strip down the leading edge.
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              child: NoteColorEdge(color: noteColor),
            ),

            if (_isText)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: EditorToolbarDock(
                  keyboardOpen: keyboardOpen,
                  child: MarkdownToolbar(
                    controller: _fleatherController,
                    focusNode: _textContentFocusNode,
                    noteColor: noteColor,
                    onColorPressed: _pickColor,
                    onImagePressed: () => _handleOcrScan(context),
                  ),
                ),
              ),

            if (_isTodo)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: EditorToolbarDock(
                  keyboardOpen: keyboardOpen,
                  child: ChecklistAddBar(
                    focusNode: _addTaskFocusNode,
                    onAdd: _addTodoItem,
                  ),
                ),
              ),

            if (showVoiceFab)
              PositionedDirectional(
                // The button reserves 10px around its 48px circle for the
                // recording pulse; offset so the circle sits at 104 / 22.
                end: VoiceFab.end - 10,
                bottom: (_isText ? VoiceFab.bottom : 40) - 10 + bottomSafe,
                child: VoiceFab(
                  recording: _isRecording,
                  elapsed: _recordedDuration,
                  semanticLabel: _isText
                      ? AppL10n.of(context).edNewVoiceNote
                      : _isRecording
                          ? AppL10n.of(context).edTapToStop
                          : AppL10n.of(context).edTapToStart,
                  onPressed: _isText
                      ? _openNewVoiceNote
                      : (_isRecording ? _stopRecording : _startRecording),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return EditorTopBar(
      embedded: widget.embedded,
      onBack: () => _handleBack(context),
      folderChip: StreamBuilder<List<NoteFolder>>(
        stream: _foldersStream,
        builder: (context, snapshot) => EditorFolderChip(
          folders: selectedFolders,
          colors: FolderPalette.resolve(snapshot.data ?? const []),
          onTap: _showFolderBottomSheet,
        ),
      ),
      pin: _isText
          ? EditorPinButton(pinned: _isPinned, onPressed: _togglePin)
          : null,
      menu: EditorOverflowMenu(
        entries: _menuEntries,
        onSelected: (value) => _onMenuSelected(context, value),
      ),
    );
  }

  /// Title, meta row and (checklists) the auto-save chip.
  Widget _buildTitleSliver() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
          SketchSpace.editorX, 26, SketchSpace.editorX, 0),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EditorTitleField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              onSubmitted: (_) {
                if (_isText) _textContentFocusNode.requestFocus();
                if (_isTodo) _addTaskFocusNode.requestFocus();
              },
            ),
            const SizedBox(height: 2),
            EditorMetaRow(
              editedAt: _editedAt,
              showEncrypted: _isText || _isTodo,
            ),
            if (_isTodo && _currentNoteId != null) ...[
              const SizedBox(height: 4),
              _AutoSaveChip(saving: _saving),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContentSlivers() {
    switch (selectedNoteType) {
      case 'Title Content':
        return _buildTextNoteContent();
      case 'Record Audio':
        return [_buildVoiceNoteContent()];
      case 'Todo List':
        return [_buildTodoListContent()];
      case 'Reminder':
        return [_buildReminderContent()];
      default:
        return const [SliverToBoxAdapter(child: SizedBox.shrink())];
    }
  }

  List<Widget> _buildTextNoteContent() {
    final l10n = AppL10n.of(context);
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
            SketchSpace.editorX, 10, SketchSpace.editorX, 0),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MarkdownEditor(
                controller: _fleatherController,
                focusNode: _textContentFocusNode,
                hintText: l10n.edBodyHint,
              ),
              if (_ocrImagePath != null) ...[
                const SizedBox(height: SketchSpace.section),
                OcrScanCard(
                  imagePath: _ocrImagePath!,
                  busy: _ocrBusy,
                  pillLabel: _ocrPillLabel(l10n),
                  onExtract: _extractOcrText,
                  onDiscard: () => setState(() => _ocrImagePath = null),
                ),
              ],
            ],
          ),
        ),
      ),
      // The rest of the page focuses the body, so a short note is still
      // easy to tap into; it also clears the toolbar and voice button.
      SliverFillRemaining(
        hasScrollBody: false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _focusBodyEnd,
          child: const SizedBox(height: 180),
        ),
      ),
    ];
  }

  void _focusBodyEnd() {
    final end = _fleatherController.document.length - 1;
    _fleatherController.updateSelection(
      TextSelection.collapsed(offset: end < 0 ? 0 : end),
    );
    _textContentFocusNode.requestFocus();
  }

  String _ocrPillLabel(AppL10n l10n) {
    if (_ocrBusy) return l10n.edExtracting;
    final premium = PremiumService();
    if (premium.isPremium) return l10n.edExtractText;
    final used = premium.getOcrScansThisMonth();
    const total = PremiumLimits.maxOcrScansPerMonthForFree;
    // Near the limit (the last quarter), show how much is left.
    return used >= total * 0.75
        ? l10n.edExtractTextQuota(used, total)
        : l10n.edExtractText;
  }

  Widget _buildVoiceNoteContent() {
    final premium = PremiumService();
    final cap = premium.getMaxVoiceRecordingDuration();
    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              SketchSpace.screenX, SketchSpace.section, SketchSpace.screenX, 0),
          sliver: SliverToBoxAdapter(
            child: VoiceNoteBody(
              recording: _isRecording,
              recorded: _recordedDuration,
              hasAudio: _audioFilePath != null,
              playing: _isPlaying,
              position: _playbackPosition,
              total: _playbackDuration.inMilliseconds > 0
                  ? _playbackDuration
                  : Duration(seconds: _audioDurationSeconds ?? 0),
              seed: _audioFilePath?.hashCode ?? 0,
              freeCapSeconds: cap > 0 ? cap : null,
              tooLargeToSyncMegabytes: _audioTooLargeForCloud
                  ? AudioUploadQueue.cloudLimitMegabytes
                  : null,
              onRecord: _startRecording,
              onPlay: _startPlayback,
              onPause: _pausePlayback,
              onStop: _stopPlayback,
              onReplace: _replaceRecording,
              onSeek: _seekPlayback,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 140)),
      ],
    );
  }

  Future<void> _seekPlayback(Duration position) async {
    // Reflect the drag immediately in the UI.
    setState(() {
      _playbackPosition = position;
    });
    // Only seek once a source is loaded; seeking before
    // playback has started throws inside audioplayers.
    if (!_hasAudioSource) return;
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      debugPrint('❌ [VoiceNote] Failed to seek: $e');
    }
  }

  Widget _buildTodoListContent() {
    return SliverMainAxisGroup(
      slivers: [
        ChecklistEditorSliver(
          items: [
            for (final item in _todoItems)
              ChecklistEntry(
                id: item.id,
                text: item.content,
                done: item.isCompleted,
              ),
          ],
          onToggle: (e) => _toggleTodoItem(e.id),
          onDelete: _deleteTodoItem,
          onReorder: _reorderTodoItems,
          onEdit: _editTodoItem,
        ),
        SliverToBoxAdapter(
          child: SizedBox(
              height: SketchSpace.dockClearance +
                  MediaQuery.paddingOf(context).bottom),
        ),
      ],
    );
  }

  // ============================================
  // Checklist items
  // ============================================

  Future<void> _reloadTodoItems() async {
    if (_currentNoteId == null) return;
    final items =
        await TodoListNoteService.watchTodoItems(_currentNoteId!).first;
    if (mounted) {
      setState(() {
        _todoItems = items;
      });
    }
  }

  Future<void> _toggleTodoItem(int itemId) async {
    // Move it in this frame; the database follows.
    setState(() {
      _todoItems = [
        for (final i in _todoItems)
          i.id == itemId ? i.copyWith(isCompleted: !i.isCompleted) : i,
      ];
    });
    try {
      await _withSaving(
          () => TodoListNoteService.toggleTodoItemCompletion(itemId));
    } catch (e) {
      debugPrint('❌ Failed to toggle todo item: $e');
    }
    await _reloadTodoItems();
  }

  Future<void> _deleteTodoItem(ChecklistEntry entry) async {
    final index = _todoItems.indexWhere((i) => i.id == entry.id);
    if (index < 0) return;
    final removed = _todoItems[index];
    final previousOrder = [for (final i in _todoItems) i.id];

    // The dismissed row must leave the tree now.
    setState(() {
      _todoItems = List.of(_todoItems)..removeAt(index);
    });

    try {
      await _withSaving(() => TodoListNoteService.deleteTodoItem(entry.id));
    } catch (e) {
      debugPrint('❌ Failed to delete todo item: $e');
      await _reloadTodoItems();
      return;
    }

    if (mounted) {
      final l10n = AppL10n.of(context);
      showSketchToast(
        context: context,
        message: l10n.edTaskDeleted,
        actionLabel: l10n.edUndo,
        onAction: () => _restoreTodoItem(removed, previousOrder),
      );
    }
    await _reloadTodoItems();
  }

  /// Undo for a swiped-away task: re-adds it with its text, state and place.
  Future<void> _restoreTodoItem(
      TodoItemEntity item, List<int> previousOrder) async {
    if (_currentNoteId == null || _todoListNoteUuid == null) return;
    try {
      await _withSaving(() async {
        final newId = await TodoListNoteService.addTodoItem(
          todoListNoteId: _currentNoteId!,
          todoListNoteUuid: _todoListNoteUuid!,
          content: item.content,
          isCompleted: item.isCompleted,
          orderIndex: item.orderIndex,
        );
        final current =
            await TodoListNoteService.watchTodoItems(_currentNoteId!).first;
        final alive = {for (final i in current) i.id};
        final order = [
          for (final id in previousOrder)
            if (id == item.id) newId else if (alive.contains(id)) id,
        ];
        await TodoListNoteService.reorderTodoItems(_currentNoteId!, order);
      });
    } catch (e) {
      debugPrint('❌ Failed to restore todo item: $e');
    }
    await _reloadTodoItems();
  }

  /// [openIds] is the new order of the open tasks; done tasks keep theirs.
  Future<void> _reorderTodoItems(List<int> openIds) async {
    if (_currentNoteId == null) return;
    final byId = {for (final i in _todoItems) i.id: i};
    final order = [
      ...openIds,
      for (final i in _todoItems)
        if (i.isCompleted) i.id,
    ];
    setState(() {
      _todoItems = [
        for (final (index, id) in order.indexed)
          if (byId[id] != null) byId[id]!.copyWith(orderIndex: index),
      ];
    });
    try {
      await _withSaving(
          () => TodoListNoteService.reorderTodoItems(_currentNoteId!, order));
    } catch (e) {
      debugPrint('❌ Failed to reorder todo items: $e');
    }
    await _reloadTodoItems();
  }

  Future<void> _editTodoItem(ChecklistEntry entry, String text) async {
    setState(() {
      _todoItems = [
        for (final i in _todoItems)
          i.id == entry.id ? i.copyWith(content: text) : i,
      ];
    });
    try {
      await _withSaving(() =>
          TodoListNoteService.updateTodoItem(itemId: entry.id, content: text));
    } catch (e) {
      debugPrint('❌ Failed to edit todo item: $e');
    }
    await _reloadTodoItems();
  }

  /// The add bar's Enter / "+". The note is created first if it is new.
  Future<void> _addTodoItem(String content) async {
    // Ensure we have a note created first
    if (_currentNoteId == null) {
      try {
        await _saveNote();
      } catch (e) {
        debugPrint('❌ Failed to create todo list note: $e');
      }
      if (_currentNoteId == null) {
        debugPrint('❌ Failed to create todo list note');
        return;
      }
    }
    await _saveTodoItemToDatabase(content);
  }

  Future<void> _saveTodoItemToDatabase(String content) async {
    try {
      if (_currentNoteId == null || _todoListNoteUuid == null) {
        debugPrint('❌ Cannot add todo item: note not created yet');
        return;
      }

      await _withSaving(() => TodoListNoteService.addTodoItem(
            todoListNoteId: _currentNoteId!,
            todoListNoteUuid: _todoListNoteUuid!,
            content: content,
          ));

      await _reloadTodoItems();
      debugPrint('✅ Added todo item');
    } catch (e) {
      debugPrint('❌ Failed to add todo item: $e');
    }
  }

  Widget _buildReminderContent() {
    return SliverMainAxisGroup(
      slivers: [
        // ReminderTypeContent already returns a SliverToBoxAdapter
        ReminderTypeContent(
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
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  // ============================================
  // Top bar actions
  // ============================================

  Future<void> _handleBack(BuildContext context) async {
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

    if (context.mounted) {
      _exitEditor(context);
    }
  }

  Future<void> _togglePin() async {
    setState(() => _isPinned = !_isPinned);
    if (_currentNoteId != null) {
      await DriftNoteService.setNotePinned(
        _currentNoteId!,
        _noteTypeToKey(selectedNoteType),
        _isPinned,
      );
    }
  }

  Future<void> _toggleArchive() async {
    setState(() => _isArchived = !_isArchived);
    if (_currentNoteId != null) {
      await DriftNoteService.setNoteArchived(
        _currentNoteId!,
        _noteTypeToKey(selectedNoteType),
        _isArchived,
      );
    }
  }

  Future<void> _pickColor() async {
    PinpointHaptics.light();
    final picked = await showNoteColorPicker(
      context,
      selected: _selectedColor,
    );
    if (picked != null && mounted) {
      setState(() => _selectedColor = picked == 'default' ? null : picked);
      // Persist immediately for already-saved notes.
      if (_currentNoteId != null) {
        await DriftNoteService.setNoteColor(
          _currentNoteId!,
          _noteTypeToKey(selectedNoteType),
          _selectedColor,
        );
      }
    }
  }

  /// The ⋯ menu, rebuilt on each open so the quota counts are current.
  List<EditorMenuEntry> _menuEntries() {
    final l10n = AppL10n.of(context);
    final premium = PremiumService();
    final isPremium = premium.isPremium;
    final exportsUsed = premium.getExportsThisMonth();
    const exportsTotal = PremiumLimits.maxExportsPerMonthForFree;

    return [
      EditorMenuEntry(
          value: 'save', icon: Icons.check_rounded, label: l10n.edSaveAndClose),
      if (!_isText)
        EditorMenuEntry(
          value: 'pin',
          icon: _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
          label: _isPinned ? l10n.edUnpin : l10n.edPin,
        ),
      EditorMenuEntry(
        value: 'archive',
        icon: _isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
        label: _isArchived ? l10n.edUnarchive : l10n.edArchive,
      ),
      EditorMenuEntry(
          value: 'color', icon: Icons.palette_outlined, label: l10n.edColor),
      if (_isText) ...[
        EditorMenuEntry(
          value: 'export_pdf',
          icon: Icons.picture_as_pdf_outlined,
          label: isPremium
              ? l10n.edExportPdf
              : l10n.edExportPdfQuota(exportsUsed, exportsTotal),
          dividerBefore: true,
        ),
        EditorMenuEntry(
          value: 'export_markdown',
          icon: Icons.file_download_outlined,
          label: isPremium
              ? l10n.edExportMarkdown
              : l10n.edExportMarkdownQuota(exportsUsed, exportsTotal),
        ),
        EditorMenuEntry(
          value: 'ocr_scan',
          icon: Icons.document_scanner_outlined,
          label: isPremium
              ? l10n.edScanText
              : l10n.edScanTextQuota(premium.getOcrScansThisMonth(),
                  PremiumLimits.maxOcrScansPerMonthForFree),
        ),
      ],
      EditorMenuEntry(
        value: 'share',
        icon: Icons.ios_share_rounded,
        label: l10n.edShare,
        dividerBefore: !_isText,
      ),
      // Encrypted sharing is not built yet: shown, disabled, labelled SOON.
      EditorMenuEntry(
        value: 'share_encrypted',
        icon: Icons.lock_outline_rounded,
        label: l10n.edShareEncrypted,
        enabled: false,
        badge: l10n.edSoonBadge,
      ),
      EditorMenuEntry(
          value: 'usage', icon: Icons.analytics_outlined, label: l10n.edUsage),
      if (_currentNoteId != null) ...[
        EditorMenuEntry(
            value: 'info',
            icon: Icons.info_outline_rounded,
            label: l10n.edInfo),
        EditorMenuEntry(
          value: 'delete',
          icon: Icons.delete_outline_rounded,
          label: l10n.commonDelete,
          destructive: true,
          dividerBefore: true,
        ),
      ],
    ];
  }

  Future<void> _onMenuSelected(BuildContext context, String value) async {
    PinpointHaptics.light();
    switch (value) {
      case 'save':
        await _saveAndClose(context);
        break;
      case 'pin':
        await _togglePin();
        break;
      case 'archive':
        await _toggleArchive();
        break;
      case 'color':
        await _pickColor();
        break;
      case 'delete':
        _handleDeleteNote(context);
        break;
      case 'share':
        _handleShareNote(context);
        break;
      case 'export_markdown':
        if (!_isText) return;
        await NoteExportActions.exportMarkdown(
          context,
          title: _titleController.text.trim(),
          document: _fleatherController.document,
        );
        break;
      case 'export_pdf':
        if (!_isText) return;
        await NoteExportActions.exportPdf(
          context,
          title: _titleController.text.trim(),
          document: _fleatherController.document,
        );
        break;
      case 'ocr_scan':
        _handleOcrScan(context);
        break;
      case 'usage':
        _showUsageStats(context);
        break;
      case 'info':
        _showNoteInfo(context);
        break;
    }
  }

  /// Explicit save, then leave (menu "Save & close", the reminder CTA).
  Future<void> _saveAndClose(BuildContext context) async {
    try {
      await _saveNote(isExplicit: true);
      if (context.mounted) {
        _exitEditor(context);
      }
    } catch (e) {
      if (context.mounted) {
        showSketchToast(
          context: context,
          message: e.toString().replaceAll('Exception: ', ''),
          tone: ToastTone.error,
        );
      }
    }
  }

  /// Opens a new voice note that starts recording (the text editor's mic).
  void _openNewVoiceNote() {
    if (_shouldSave()) {
      _autoSaveTimer?.cancel();
      unawaited(_saveNote().catchError((Object e) {
        debugPrint('⚠️ [CreateNoteV2] Save before voice note failed: $e');
      }));
    }
    context.push(
      CreateNoteScreenV2.kRouteName,
      extra: const CreateNoteScreenArguments(
        noticeType: 'Record Audio',
        autoStartRecording: true,
      ),
    );
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

      // Not the cache directory, which Android may clear at any time.
      final audioPath = await VoiceRecordingFiles.newRecordingPath();

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

      // Start timer to update duration, stopping free users at the cap.
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _recordedDuration =
              Duration(seconds: _recordedDuration.inSeconds + 1);
        });

        // A negative max means unlimited (premium). Free recordings stop at
        // PremiumLimits.maxVoiceRecordingDurationForFree and offer the upgrade
        // — the audio recorded so far is kept, never discarded.
        final maxDuration = PremiumService().getMaxVoiceRecordingDuration();
        if (maxDuration > 0 && _recordedDuration.inSeconds >= maxDuration) {
          unawaited(_stopRecordingAtFreeLimit());
        }
      });

      debugPrint('🎤 [VoiceNote] Started recording to: $audioPath');
    } catch (e) {
      debugPrint('❌ [VoiceNote] Failed to start recording: $e');
    }
  }

  /// Stop because a free user reached the recording cap, then offer Premium.
  ///
  /// The recording is stopped and kept first, so the user never loses what they
  /// just said; the gate is a prompt about the *next* recording, not a
  /// punishment for this one.
  Future<void> _stopRecordingAtFreeLimit() async {
    _recordingTimer?.cancel();
    if (!_isRecording) return;

    await _stopRecording();
    if (!mounted) return;
    await PremiumGateDialog.showVoiceRecordingLimit(context);
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _recordingTimer?.cancel();

      final tooLarge =
          path != null && await AudioUploadQueue.tooLargeForCloud(path);
      if (path != null && mounted) {
        setState(() {
          _audioFilePath = path;
          _audioTooLargeForCloud = tooLarge;
          _audioDurationSeconds = _recordedDuration.inSeconds;
          _isRecording = false;
        });
        _scheduleAutoSave();
        getIt<AnalyticsFacade>()
            .trackAudioRecorded(durationSeconds: _recordedDuration.inSeconds);
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
        _hasAudioSource = true;
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
            debugPrint(
                '🗑️ [VoiceNote] Deleted old audio file: $_audioFilePath');
          }
        } catch (e) {
          debugPrint('⚠️ [VoiceNote] Failed to delete old audio file: $e');
          // Continue anyway - we'll overwrite the path
        }
      }

      // Clear audio state
      setState(() {
        _audioFilePath = null;
        _audioTooLargeForCloud = false;
        _audioDurationSeconds = null;
        _recordedDuration = Duration.zero;
        _playbackPosition = Duration.zero;
        _playbackDuration = Duration.zero;
        _isPlaying = false;
        _hasAudioSource = false;
      });

      // Trigger auto-save to update the note (remove audio)
      _scheduleAutoSave();

      debugPrint('🔄 [VoiceNote] Ready to record again');
    } catch (e) {
      debugPrint('❌ [VoiceNote] Failed to replace recording: $e');
    }
  }

  /// Handle delete note
  Future<void> _handleDeleteNote(BuildContext context) async {
    if (_currentNoteId == null) return;
    final l10n = AppL10n.of(context);

    final confirmed = await showSketchConfirm(
      context: context,
      title: l10n.edDeleteNoteTitle,
      message: l10n.edDeleteNoteConfirm,
      confirmLabel: l10n.commonDelete,
      cancelLabel: l10n.commonCancel,
    );
    if (!confirmed || _currentNoteId == null) return;

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

    getIt<AnalyticsFacade>()
        .trackNoteDeleted(noteType: _noteTypeToKey(selectedNoteType));

    // Return to previous screen (or clear the detail pane when embedded)
    if (context.mounted) {
      _exitEditor(context);
    }
  }

  /// Show note info sheet
  void _showNoteInfo(BuildContext context) {
    if (_currentNoteId == null) return;
    final l10n = AppL10n.of(context);
    final typeLabel = switch (selectedNoteType) {
      'Title Content' => l10n.noteTypeText,
      'Todo List' => l10n.noteTypeChecklist,
      'Record Audio' => l10n.noteTypeVoice,
      'Reminder' => l10n.noteTypeReminder,
      _ => selectedNoteType,
    };

    showSketchSheet<void>(
      context: context,
      builder: (ctx) => SketchSheet(
        title: l10n.edNoteInfo,
        child: SketchGroup(
          margin: EdgeInsets.zero,
          children: [
            _InfoRow(label: l10n.edInfoType, value: typeLabel),
            _InfoRow(label: 'ID', value: _currentNoteId.toString()),
            _InfoRow(
              label: l10n.edInfoFolder,
              value: selectedFolders.isEmpty
                  ? l10n.edInfoNone
                  : selectedFolders.map((f) => f.title).join(', '),
            ),
          ],
        ),
      ),
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
      final l10n = AppL10n.of(context);
      showWarningToast(
        context: context,
        title: l10n.edNothingToShare,
        description: l10n.edAddContentBeforeShare,
      );
      return;
    }

    SharePlus.instance.share(
      ShareParams(
        text: '$title\n\n$content',
        subject: title,
      ),
    );

    getIt<AnalyticsFacade>().trackNoteShared();
    PinpointHaptics.success();
  }

  /// OCR, step 1: check the quota, then pick an image into the scan card.
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
      // Cap the long edge so a very large gallery image (e.g. 48MP) can't spike
      // memory / OOM while being read for OCR. 3000px keeps text crisp enough
      // for ML Kit recognition on normal photos; quality stays high (no
      // imageQuality downsizing) to preserve fine text edges.
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 3000,
        maxHeight: 3000,
      );

      if (image == null || !mounted) return;
      setState(() {
        _ocrImagePath = image.path;
        _ocrBusy = false;
      });
    } catch (e) {
      debugPrint('Error picking image for OCR: $e');
      PinpointHaptics.error();
      if (context.mounted) {
        showErrorToast(
          context: context,
          title: AppL10n.of(context).edOcrFailed,
          description: AppL10n.of(context).edOcrFailedBody,
        );
      }
    }
  }

  /// OCR, step 2 ("Extract text"): recognise and append to the note.
  Future<void> _extractOcrText() async {
    final path = _ocrImagePath;
    if (path == null || _ocrBusy) return;

    final premiumService = PremiumService();
    if (!premiumService.canPerformOcrScan()) {
      PinpointHaptics.error();
      await PremiumGateDialog.showOcrLimit(
          context, premiumService.getRemainingOcrScans());
      return;
    }

    setState(() => _ocrBusy = true);
    try {
      final String recognizedText = await OCRService.recognizeText(path);
      if (!mounted) return;

      if (recognizedText.isEmpty) {
        PinpointHaptics.error();
        setState(() => _ocrBusy = false);
        showErrorToast(
          context: context,
          title: AppL10n.of(context).edNoTextFound,
          description: AppL10n.of(context).edNoTextFoundBody,
        );
        return;
      }

      // Append into the live document. This used to serialize the document to
      // a JSON delta, string-concatenate the OCR text onto it, and parse the
      // result back: that produced invalid JSON, so the raw delta was dumped
      // into the note body as visible text, the document lost its trailing
      // line break (which later crashed the editor from the keyboard path),
      // and all existing formatting was destroyed. Replacing the controller
      // without setState also left the editor bound to the old one.
      final document = _fleatherController.document;
      final hasExistingText = document.toPlainText().trim().isNotEmpty;
      document.insert(
        document.length - 1, // Before the document's trailing line break.
        hasExistingText ? '\n\n$recognizedText' : recognizedText,
      );
      _scheduleAutoSave();

      await premiumService.incrementOcrScans();

      getIt<AnalyticsFacade>().trackOcrPerformed();
      PinpointHaptics.success();
      if (mounted) {
        setState(() {
          _ocrImagePath = null;
          _ocrBusy = false;
        });
        showSuccessToast(
          context: context,
          title: AppL10n.of(context).edTextExtracted,
          description: AppL10n.of(context).edTextExtractedBody,
        );
      }
    } catch (e) {
      debugPrint('Error performing OCR: $e');
      PinpointHaptics.error();
      if (mounted) {
        setState(() => _ocrBusy = false);
        showErrorToast(
          context: context,
          title: AppL10n.of(context).edOcrFailed,
          description: AppL10n.of(context).edOcrFailedBody,
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

/// The checklist's outline chip: "Auto-saved", flashing "Saving…" while a
/// write is in flight.
class _AutoSaveChip extends StatelessWidget {
  const _AutoSaveChip({required this.saving});

  final ValueListenable<bool> saving;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;
    final t = context.type;
    return ValueListenableBuilder<bool>(
      valueListenable: saving,
      builder: (context, isSaving, _) => Semantics(
        liveRegion: true,
        child: AnimatedContainer(
          duration: SketchMotion.of(context, SketchMotion.base),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: ShapeDecoration(
            color: isSaving ? s.soft : Colors.transparent,
            shape: StadiumBorder(
              side: BorderSide(color: s.outline, width: SketchStroke.pastel),
            ),
          ),
          child: AnimatedSwitcher(
            duration:
                SketchMotion.of(context, const Duration(milliseconds: 150)),
            child: Center(
              key: ValueKey(isSaving),
              widthFactor: 1,
              child: Text(
                isSaving ? l10n.edSaving : l10n.edAutoSaved,
                style: t.chip.copyWith(fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: t.bodySmall.copyWith(color: s.muted)),
          ),
          Expanded(child: Text(value, style: t.body)),
        ],
      ),
    );
  }
}
