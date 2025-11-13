import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/screens/create_note_screen.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:provider/provider.dart';
import '../constants/constants.dart';
import '../design_system/design_system.dart';
import '../services/filter_service.dart';
import '../util/note_utils.dart';

class FolderScreen extends StatefulWidget {
  static const String kRouteName = '/folder';
  final int folderId;
  final String folderTitle;

  const FolderScreen({
    super.key,
    required this.folderId,
    required this.folderTitle,
  });

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  String _searchQuery = '';
  bool _isSearchActive = false;
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchInputChanged);
  }

  void _onSearchInputChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GradientScaffold(
      appBar: GlassAppBar(
        title: _isSearchActive
            ? SearchBarSticky(
                controller: _searchController,
                hint: 'Search in folder...',
                onSearch: (query) {
                  setState(() => _searchQuery = query);
                },
                autoFocus: true,
              )
            : Row(
                children: [
                  Icon(Icons.folder_rounded, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(widget.folderTitle),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'Search',
                    onPressed: () {
                      setState(() => _isSearchActive = !_isSearchActive);
                    },
                  ),
                ],
              ),
      ),
      body: Consumer<FilterService>(
        builder: (context, filterService, _) {
          return StreamBuilder<List<NoteWithDetails>>(
            stream: DriftNoteService.watchNotesWithDetailsByFolder(
              folderId: widget.folderId,
              searchQuery: _searchQuery,
              filterOptions: filterService.filterOptions,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Error loading notes',
                  message: 'Please try again later',
                );
              }
              final notes = snapshot.data ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(
                          widget.folderTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TagChip(
                          label: '${notes.length}',
                          color: cs.primary,
                          size: TagChipSize.small,
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: notes.isEmpty
                        ? EmptyState(
                            icon: Icons.folder_open_rounded,
                            title: 'No notes in this folder',
                            message:
                                'Add notes to this folder to see them here',
                          )
                        : AnimatedListStagger(
                            itemCount: notes.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemBuilder: (context, index) {
                              final note = notes[index];
                              final hasTitle = note.note.noteTitle != null &&
                                  note.note.noteTitle!.trim().isNotEmpty;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: NoteCard(
                                  title: getNoteTitleOrPreview(
                                      note.note.noteTitle, note.textContent),
                                  excerpt: hasTitle ? note.textContent : null,
                                  lastModified: note.note.updatedAt,
                                  isPinned: note.note.isPinned,
                                  tags: note.folders
                                      .map((f) => CardNoteTag(
                                            label: f.title,
                                            color: theme.colorScheme.primary,
                                          ))
                                      .toList(),
                                  onTap: () {
                                    PinpointHaptics.medium();
                                    context.push(
                                      CreateNoteScreen.kRouteName,
                                      extra: CreateNoteScreenArguments(
                                        noticeType: getNoteTypeDisplayName(
                                            note.note.noteType),
                                        existingNote: note,
                                      ),
                                    );
                                  },
                                  onPinToggle: () {
                                    PinpointHaptics.light();
                                    DriftNoteService.togglePinStatus(
                                      note.note.id,
                                      !note.note.isPinned,
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
