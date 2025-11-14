import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

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
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  Timer? _recordingTimer;
  Duration _recordedDuration = Duration.zero;

  // Todo list fields
  final List<String> _todoItems = [];

  // Reminder fields
  DateTime? _reminderTime;
  late TextEditingController _reminderDescriptionController;

  // Save tracking
  int? _currentNoteId; // Track saved note ID
  bool _isSaving = false;
  Timer? _autoSaveTimer; // Auto-save timer

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _titleFocusNode = FocusNode();
    _textContentController = TextEditingController();
    _textContentFocusNode = FocusNode();
    _reminderDescriptionController = TextEditingController();

    // Add auto-save listeners
    _titleController.addListener(_scheduleAutoSave);
    _textContentController.addListener(_scheduleAutoSave);
    _reminderDescriptionController.addListener(_scheduleAutoSave);

    // Initialize folders
    _initializeFolders();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _titleFocusNode.dispose();
    _textContentController.dispose();
    _textContentFocusNode.dispose();
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
        final content = _textContentController.text.trim();
        hasContent = title.isNotEmpty || content.isNotEmpty;
        break;

      case 'Record Audio':
        hasContent = _audioFilePath != null;
        break;

      case 'Todo List':
        hasContent = _todoItems.isNotEmpty && _todoItems.any((item) => item.trim().isNotEmpty);
        break;

      case 'Reminder':
        hasContent = _reminderTime != null;
        break;
    }

    if (!hasContent) {
      debugPrint('⏭️ [CreateNoteV2] Auto-save skipped: No content');
      return;
    }

    debugPrint('💾 [CreateNoteV2] Auto-saving note (type: $selectedNoteType)...');

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
                  // Metadata Section (Note Type + Folder bubbles)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: _buildMetadataSection(cs, isDark),
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

              // Save before exiting
              if (_shouldSave()) {
                await _saveNote();
              }

              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          ),

          const SizedBox(width: 8),

          // Title Input
          Expanded(
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
                  fontSize: 18,
                ),
              ),
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
              maxLines: 1,
              textInputAction: TextInputAction.done,
            ),
          ),

          const SizedBox(width: 8),

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
      child: MarkdownEditor(
        controller: _textContentController,
        focusNode: _textContentFocusNode,
        hintText: 'Write your note in markdown...',
        showToolbar: true,
        enablePreview: true,
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
            // Recording indicator / status
            if (_isRecording || _audioFilePath != null) ...[
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
                        if (_isRecording)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: cs.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (_isRecording) const SizedBox(width: 12),
                        Text(
                          _isRecording ? 'Recording...' : 'Recording Complete',
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
                  : (_audioFilePath != null
                      ? 'Tap to record again'
                      : 'Tap to start recording'),
              style: TextStyle(
                fontSize: 15,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),

            // Playback controls (only show if we have a recording)
            if (_audioFilePath != null && !_isRecording) ...[
              const SizedBox(height: 32),
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
                      side:
                          BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                  ),
                ],
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
                    // Checkbox placeholder (not interactive in create mode)
                    Icon(
                      Symbols.radio_button_unchecked,
                      size: 20,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 12),
                    // Todo text
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 15,
                          color: cs.onSurface,
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
                      onPressed: () {
                        setState(() {
                          _todoItems.removeAt(index);
                        });
                        _scheduleAutoSave();
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

  void _addTodoItem() {
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
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              setState(() {
                _todoItems.add(value.trim());
              });
              _scheduleAutoSave();
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _todoItems.add(controller.text.trim());
                });
                _scheduleAutoSave();
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderContent() {
    final cs = Theme.of(context).colorScheme;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description Field
            Text(
              "Description",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _reminderDescriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "What would you like to be reminded about?",
                  hintStyle: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: cs.onSurface,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Reminder Time
            Text(
              "Reminder Time",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickReminderDateTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Symbols.schedule,
                      color: cs.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _reminderTime == null
                            ? "Select Date & Time"
                            : _formatReminderDateTime(_reminderTime!),
                        style: TextStyle(
                          fontSize: 15,
                          color: _reminderTime == null
                              ? cs.onSurface.withValues(alpha: 0.5)
                              : cs.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      Symbols.chevron_right,
                      size: 18,
                      color: cs.onSurface.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
    final hasContent = _textContentController.text.trim().isNotEmpty;
    final hasTodos = _todoItems.any((item) => item.isNotEmpty);
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
      });
      debugPrint('⏹️ [VoiceNote] Stopped playback');
    } catch (e) {
      debugPrint('❌ [VoiceNote] Failed to stop playback: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// Build metadata section with floating bubbles (matching original design)
  Widget _buildMetadataSection(ColorScheme cs, bool isDark) {
    return Row(
      children: [
        // Note Type Bubble
        Flexible(
          child: _buildFloatingBubble(
            label: _getLabelForNoteType(selectedNoteType),
            icon: _getIconForNoteType(selectedNoteType),
            color: cs.primary,
            cs: cs,
            isDark: isDark,
            onTap: () {
              PinpointHaptics.light();
              _showNoteTypeBottomSheet(cs, isDark);
            },
          ),
        ),

        const SizedBox(width: 12),

        // Folder Bubble
        Flexible(
          child: _buildFloatingBubble(
            label: selectedFolders.isEmpty
                ? 'Add Folder'
                : selectedFolders.first.title,
            icon: Symbols.folder,
            color: cs.secondary,
            cs: cs,
            isDark: isDark,
            onTap: () => _showFolderBottomSheet(),
          ),
        ),
      ],
    );
  }

  /// Build floating bubble (matching original create_note_screen design)
  Widget _buildFloatingBubble({
    required String label,
    required IconData icon,
    required Color color,
    required ColorScheme cs,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: isDark ? 0.2 : 0.15),
              color.withValues(alpha: isDark ? 0.1 : 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.3 : 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                      letterSpacing: 0.2,
                    ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  /// Show note type selection bottom sheet
  void _showNoteTypeBottomSheet(ColorScheme cs, bool isDark) {
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
              'Select Note Type',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 24),
            ...kNoteTypes.map((type) {
              final isSelected = selectedNoteType == type;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(_getIconForNoteType(type), color: cs.primary),
                  title: Text(_getLabelForNoteType(type)),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: cs.primary)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: cs.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  selected: isSelected,
                  onTap: () {
                    PinpointHaptics.light();
                    setState(() => selectedNoteType = type);
                    Navigator.pop(context);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Get icon for note type
  IconData _getIconForNoteType(String noteType) {
    switch (noteType) {
      case 'Title Content':
        return Symbols.edit_note;
      case 'Record Audio':
        return Symbols.mic;
      case 'Todo List':
        return Symbols.check_box;
      case 'Reminder':
        return Symbols.alarm;
      default:
        return Symbols.note;
    }
  }

  /// Get label for note type
  String _getLabelForNoteType(String noteType) {
    return noteType; // kNoteTypes already contains display names
  }
}
