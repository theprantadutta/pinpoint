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

import '../components/create_note_screen/create_note_categories.dart';
import '../components/create_note_screen/show_note_folder_bottom_sheet.dart';
import '../constants/constants.dart';
import '../design_system/design_system.dart';
import '../dtos/note_folder_dto.dart';
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: cs.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cs.secondary.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Symbols.folder,
                                color: cs.secondary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                selectedFolders.isEmpty
                                    ? 'Add Folder'
                                    : selectedFolders.first.title,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: cs.secondary,
                                ),
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  contentPadding: EdgeInsets.zero,
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

          const SizedBox(width: 8),

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
                      Icon(Icons.delete_outline_rounded, size: 20, color: cs.error),
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
                      Icon(Icons.document_scanner_rounded, size: 20, color: cs.primary),
                      const SizedBox(width: 12),
                      Builder(
                        builder: (context) {
                          final premiumService = PremiumService();
                          final isPremium = premiumService.isPremium;
                          final used = premiumService.getOcrScansThisMonth();
                          final total = PremiumLimits.maxOcrScansPerMonthForFree;

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
                      Icon(Icons.file_download_rounded, size: 20, color: cs.primary),
                      const SizedBox(width: 12),
                      const Text('Export Markdown'),
                      const SizedBox(width: 4),
                      if (!PremiumService().isPremium)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      Icon(Icons.picture_as_pdf_rounded, size: 20, color: cs.primary),
                      const SizedBox(width: 12),
                      const Text('Export PDF'),
                      const SizedBox(width: 4),
                      if (!PremiumService().isPremium)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    Icon(Icons.lock_outline_rounded, size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
                    const SizedBox(width: 12),
                    Text('Share Encrypted', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4))),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      Icon(Icons.info_outline_rounded, size: 20, color: cs.primary),
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

  /// Handle delete note
  void _handleDeleteNote(BuildContext context, ColorScheme cs) {
    if (_currentNoteId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

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
        content = _textContentController.text.trim();
        break;
      case 'Todo List':
        content = _todoItems.where((item) => item.isNotEmpty).join('\n');
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
    final content = _textContentController.text.trim();

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
    final content = _textContentController.text.trim();

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

      final currentText = _textContentController.text;
      final newText = currentText.isEmpty
          ? recognizedText
          : '$currentText\n\n$recognizedText';
      _textContentController.text = newText;

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
