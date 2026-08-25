import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:pinpoint/util/note_utils.dart';
import '../design_system/design_system.dart';
import '../service_locators/init_service_locators.dart';
import '../services/analytics/analytics_facade.dart';
import '../services/crash_breadcrumbs.dart';
import 'create_note_screen_v2.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/widgets/pinpoint_popup_menu_button.dart';

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
  void initState() {
    super.initState();
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'Todo');
  }

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
            Text(AppL10n.of(context).todosTitle),
          ],
        ),
        actions: [
          PinpointPopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: AppL10n.of(context).todosFilter,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onOpened: () => CrashBreadcrumbs.popupMenuOpened('todos.filter'),
            onCanceled: () => CrashBreadcrumbs.popupMenuClosed('todos.filter'),
            onSelected: (String result) {
              CrashBreadcrumbs.popupMenuClosed('todos.filter',
                  selected: result);
              PinpointHaptics.selection();
              getIt<AnalyticsFacade>().trackTodoFilterChanged(filter: result);
              setState(() {
                _filter = result;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'all',
                child: Text(AppL10n.of(context).todosAll),
              ),
              PopupMenuItem<String>(
                value: 'pending',
                child: Text(AppL10n.of(context).todosPending),
              ),
              PopupMenuItem<String>(
                value: 'completed',
                child: Text(AppL10n.of(context).todosCompleted),
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
                      ? AppL10n.of(context).todosAll
                      : _filter == 'pending'
                          ? AppL10n.of(context).todosPending
                          : AppL10n.of(context).todosCompleted,
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
                    title: AppL10n.of(context).todosLoadError,
                    message: AppL10n.of(context).commonTryAgainLater,
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
                        ? AppL10n.of(context).todosNoneYet
                        : _filter == 'pending'
                            ? AppL10n.of(context).todosNonePending
                            : AppL10n.of(context).todosNoneCompleted,
                    message: _filter == 'all'
                        ? AppL10n.of(context).todosEmptyHint
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
