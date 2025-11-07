import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/screens/create_note_screen.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import '../design_system/design_system.dart';

class NotesScreen extends StatefulWidget {
  static const String kRouteName = '/notes';

  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _isGridView = false;
  String _searchQuery = '';
  String _sortBy = 'updatedAt';
  String _sortDirection = 'desc';
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GradientScaffold(
      appBar: GlassAppBar(
        scrollController: _scrollController,
        title: Row(
          children: [
            const Text('Notes'),
            const SizedBox(width: 8),
            StreamBuilder<List<NoteWithDetails>>(
              stream: DriftNoteService.watchNotesWithDetails(
                _searchQuery,
                _sortBy,
                _sortDirection,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox();
                }
                final notes = snapshot.data ?? [];
                return TagChip(
                  label: '${notes.length}',
                  color: cs.primary,
                  size: TagChipSize.small,
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            onPressed: () {
              PinpointHaptics.light();
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            tooltip: _isGridView ? 'List view' : 'Grid view',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (String result) {
              PinpointHaptics.selection();
              setState(() {
                if (result.startsWith('sort:')) {
                  _sortBy = result.substring(5);
                } else if (result.startsWith('dir:')) {
                  _sortDirection = result.substring(4);
                }
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'sort:updatedAt',
                child: Text('Sort by Last Modified'),
              ),
              const PopupMenuItem<String>(
                value: 'sort:createdAt',
                child: Text('Sort by Date Created'),
              ),
              const PopupMenuItem<String>(
                value: 'sort:title',
                child: Text('Sort by Title'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'dir:desc',
                child: Text('Descending'),
              ),
              const PopupMenuItem<String>(
                value: 'dir:asc',
                child: Text('Ascending'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBarSticky(
              hint: 'Search notes...',
              onSearch: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Content
          Expanded(
            child: StreamBuilder<List<NoteWithDetails>>(
              stream: DriftNoteService.watchNotesWithDetails(
                _searchQuery,
                _sortBy,
                _sortDirection,
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

                if (notes.isEmpty) {
                  return EmptyState(
                    icon: Icons.note_alt_outlined,
                    title: 'No notes found',
                    message: _searchQuery.isEmpty
                        ? 'Create your first note to get started'
                        : 'Try a different search',
                  );
                }

                return _isGridView
                    ? _buildGridView(notes)
                    : _buildListView(notes);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(List<NoteWithDetails> notes) {
    final theme = Theme.of(context);
    return AnimatedListStagger(
      itemCount: notes.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final note = notes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NoteCard(
            title: note.note.noteTitle ?? 'Untitled',
            excerpt: note.note.contentPlainText,
            lastModified: note.note.updatedAt,
            isPinned: note.note.isPinned,
            tags: [
              ...note.folders.map(
                (f) => CardNoteTag(
                  label: f.title,
                  color: theme.colorScheme.primary,
                ),
              ),
              ...note.tags.map(
                (t) => CardNoteTag(
                  label: t.tagTitle,
                  color: TagColors.getPreset(0).foreground,
                ),
              ),
            ],
            onTap: () {
              PinpointHaptics.medium();
              context.push(
                CreateNoteScreen.kRouteName,
                extra: CreateNoteScreenArguments(
                  noticeType: note.note.defaultNoteType,
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
    );
  }

  Widget _buildGridView(List<NoteWithDetails> notes) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: AnimatedGridStagger(
        itemCount: notes.length,
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        itemBuilder: (context, index) {
          final note = notes[index];
          return NoteCard(
            title: note.note.noteTitle ?? 'Untitled',
            excerpt: note.note.contentPlainText,
            lastModified: note.note.updatedAt,
            isPinned: note.note.isPinned,
            tags: [
              ...note.folders.map(
                (f) => CardNoteTag(
                  label: f.title,
                  color: theme.colorScheme.primary,
                ),
              ),
              ...note.tags.map(
                (t) => CardNoteTag(
                  label: t.tagTitle,
                  color: TagColors.getPreset(0).foreground,
                ),
              ),
            ],
            onTap: () {
              PinpointHaptics.medium();
              context.push(
                CreateNoteScreen.kRouteName,
                extra: CreateNoteScreenArguments(
                  noticeType: note.note.defaultNoteType,
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
          );
        },
      ),
    );
  }
}
