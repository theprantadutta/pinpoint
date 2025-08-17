import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/design/widgets/note_card.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/screens/create_note_screen.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:pinpoint/design/app_theme.dart';
import 'package:pinpoint/components/shared/empty_state_widget.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (String result) {
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Glass(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              borderRadius: AppTheme.radiusM,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  prefixIcon: const Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient background
          Glass(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Notes',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StreamBuilder<List<NoteWithDetails>>(
                        stream: DriftNoteService.watchNotesWithDetails(
                          _searchQuery,
                          _sortBy,
                          _sortDirection,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox();
                          }
                          final notes = snapshot.data ?? [];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: cs.primary.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Text(
                              '${notes.length}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          );
                        }),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.primary.withValues(alpha: 0.22),
                        cs.primary.withValues(alpha: 0.0),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

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
                  return Center(
                    child: EmptyStateWidget(
                      message: 'Error loading notes: ${snapshot.error}',
                      iconData: Icons.error_outline,
                    ),
                  );
                }

                final notes = snapshot.data ?? [];

                if (notes.isEmpty) {
                  return const Center(
                    child: EmptyStateWidget(
                      message: 'No notes found',
                      iconData: Icons.note_alt_outlined,
                    ),
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NoteCard(
            title: note.note.noteTitle,
            preview: note.note.contentPlainText,
            pinned: note.note.isPinned,
            updatedAt: note.note.updatedAt,
            reminderTime: note.note.reminderTime,
            tags: note.tags.map((t) => t.tagTitle).toList(),
            onTap: () {
              // Navigate to note detail screen
              context.push(
                CreateNoteScreen.kRouteName,
                extra: CreateNoteScreenArguments(
                  noticeType: note.note.defaultNoteType,
                  existingNote: note,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildGridView(List<NoteWithDetails> notes) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          return NoteCard(
            title: note.note.noteTitle,
            preview: note.note.contentPlainText,
            pinned: note.note.isPinned,
            updatedAt: note.note.updatedAt,
            reminderTime: note.note.reminderTime,
            tags: note.tags.map((t) => t.tagTitle).toList(),
            onTap: () {
              // Navigate to note detail screen
              context.push(
                CreateNoteScreen.kRouteName,
                extra: CreateNoteScreenArguments(
                  noticeType: note.note.defaultNoteType,
                  existingNote: note,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
