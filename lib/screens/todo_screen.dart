import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:pinpoint/util/note_utils.dart';
import '../design_system/design_system.dart';
import 'create_note_screen_v2.dart';

class TodoScreen extends StatefulWidget {
  static const String kRouteName = '/todo';

  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen>
    with AutomaticKeepAliveClientMixin {
  String _filter = 'all'; // all, completed, pending

  // Cache for last loaded data to avoid loading flash
  List<NoteWithDetails>? _cachedTodos;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GradientScaffold(
      appBar: GlassAppBar(
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: cs.primary, size: 20),
            const SizedBox(width: 8),
            const Text('Todos'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Filter',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (String result) {
              PinpointHaptics.selection();
              setState(() {
                _filter = result;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'all',
                child: Text('All Todos'),
              ),
              const PopupMenuItem<String>(
                value: 'pending',
                child: Text('Pending'),
              ),
              const PopupMenuItem<String>(
                value: 'completed',
                child: Text('Completed'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  _filter == 'all'
                      ? 'All Todos'
                      : _filter == 'pending'
                          ? 'Pending'
                          : 'Completed',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),
                StreamBuilder<List<NoteWithDetails>>(
                  stream: DriftNoteService.watchNotesWithDetailsV2(
                    excludeNoteTypes: ['text', 'voice', 'reminder'],
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox();
                    }
                    final allNotes = snapshot.data ?? [];
                    final filteredNotes = _filterTodoNotes(allNotes, _filter);
                    return TagChip(
                      label: '${filteredNotes.length}',
                      color: cs.primary,
                      size: TagChipSize.small,
                    );
                  },
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: StreamBuilder<List<NoteWithDetails>>(
              stream: DriftNoteService.watchNotesWithDetailsV2(
                excludeNoteTypes: ['text', 'voice', 'reminder'], // Only show todo notes
              ),
              builder: (context, snapshot) {
                // Use cached data while waiting to avoid loading flash
                if (snapshot.connectionState == ConnectionState.waiting) {
                  if (_cachedTodos != null) {
                    final filteredNotes = _filterTodoNotes(_cachedTodos!, _filter);
                    return _buildTodoList(filteredNotes);
                  }
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  debugPrint('❌ [TodoScreen] Error loading todos: ${snapshot.error}');
                  debugPrint('❌ [TodoScreen] Stack trace: ${snapshot.stackTrace}');
                  return EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Error loading todos',
                    message: 'Please try again later',
                  );
                }

                final allNotes = snapshot.data ?? [];
                // Cache the data for next time
                _cachedTodos = allNotes;
                final filteredNotes = _filterTodoNotes(allNotes, _filter);

                if (filteredNotes.isEmpty) {
                  return EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: _filter == 'all'
                        ? 'No todos yet'
                        : _filter == 'pending'
                            ? 'No pending todos'
                            : 'No completed todos',
                    message: _filter == 'all'
                        ? 'Create notes with todo lists to see them here'
                        : '',
                  );
                }

                return _buildTodoList(filteredNotes);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton(
          onPressed: () {
            PinpointHaptics.medium();
            // Navigate to create note screen with Todo List pre-selected
            context.push(
              CreateNoteScreenV2.kRouteName,
              extra: CreateNoteScreenArguments(
                noticeType: 'Todo List',
              ),
            );
          },
          child: const Icon(Icons.add_rounded),
        ),
      ),
    );
  }

  Widget _buildTodoList(List<NoteWithDetails> filteredNotes) {
    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
      itemCount: filteredNotes.length,
      itemBuilder: (context, index) {
        final note = filteredNotes[index];
        final hasTitle = note.note.noteTitle != null && note.note.noteTitle!.trim().isNotEmpty;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NoteCard(
            title: getNoteTitleOrPreview(note.note.noteTitle, note.textContent),
            excerpt: hasTitle ? note.textContent : null,
            lastModified: note.note.updatedAt,
            isPinned: note.note.isPinned,
            noteType: note.note.noteType,
            totalTasks: note.todoItems.length,
            completedTasks: note.todoItems.where((item) => item.isDone).length,
            tags: [
              ...note.folders.map(
                (f) => CardNoteTag(
                  label: f.title,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
            onTap: () {
              PinpointHaptics.medium();
              context.push(
                CreateNoteScreenV2.kRouteName,
                extra: CreateNoteScreenArguments(
                  noticeType: 'Todo List',
                  existingNote: note,
                ),
              );
            },
            onPinToggle: () {
              PinpointHaptics.light();
              DriftNoteService.togglePinStatus(note.note.id, !note.note.isPinned);
            },
          ),
        );
      },
    );
  }

  List<NoteWithDetails> _filterTodoNotes(
      List<NoteWithDetails> notes, String filter) {
    switch (filter) {
      case 'completed':
        // Show notes where ALL tasks are completed
        return notes.where((note) {
          if (note.todoItems.isEmpty) return false;
          return note.todoItems.every((item) => item.isDone);
        }).toList();
      case 'pending':
        // Show notes that have at least one pending task
        return notes.where((note) {
          if (note.todoItems.isEmpty) return true;
          return note.todoItems.any((item) => !item.isDone);
        }).toList();
      case 'all':
      default:
        return notes;
    }
  }

}
