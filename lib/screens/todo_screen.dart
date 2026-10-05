import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:pinpoint/util/note_utils.dart';

import '../components/shared/note_grid.dart';
import '../database/database.dart';
import '../design_system/design_system.dart';
import '../navigation/new_note.dart';
import '../service_locators/init_service_locators.dart';
import '../services/analytics/analytics_facade.dart';
import '../services/todo_list_note_service.dart';
import 'create_note_screen_v2.dart';

/// Dock tab 4: every checklist, grouped by note. Each group is a compact
/// [ProgressCard] (tap to open the note) followed by its [ChecklistRow]s —
/// open items first, then done — which toggle in place.
class TodoScreen extends StatefulWidget {
  static const String kRouteName = '/todo';

  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen>
    with AutomaticKeepAliveClientMixin {
  String _filter = 'all'; // all, completed, pending

  late final Stream<List<NoteWithDetails>> _stream =
      DriftNoteService.watchNotesWithDetailsV2(
    excludeNoteTypes: ['text', 'voice', 'reminder'], // Only todo notes
  );

  // Cache for last loaded data to avoid loading flash
  List<NoteWithDetails>? _cachedTodos;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'Todo');
  }

  void _setFilter(String filter) {
    if (filter == _filter) return;
    PinpointHaptics.selection();
    getIt<AnalyticsFacade>().trackTodoFilterChanged(filter: filter);
    setState(() => _filter = filter);
  }

  void _open(NoteWithDetails note) {
    PinpointHaptics.medium();
    context.push(
      CreateNoteScreenV2.kRouteName,
      extra: CreateNoteScreenArguments(
        noticeType: NewNote.checklist,
        existingNote: note,
      ),
    );
  }

  Future<void> _toggle(NoteTodoItem item, bool done) async {
    await TodoListNoteService.updateTodoItem(
        itemId: item.id, isCompleted: done);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final l10n = AppL10n.of(context);
    final s = context.sketch;

    return SketchScaffold(
      largeTitle: true,
      title: l10n.todosTitle,
      showBack: false,
      doodleTop: DoodleBackground.todoTop,
      actions: [
        CircleIconButton(
          icon: Icons.add_rounded,
          iconSize: 24,
          fill: s.inverse,
          semanticLabel: l10n.lsNewChecklist,
          onPressed: () {
            PinpointHaptics.medium();
            NewNote.open(context, NewNote.checklist);
          },
        ),
      ],
      body: StreamBuilder<List<NoteWithDetails>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasData) _cachedTodos = snapshot.data;
          final all = snapshot.data ?? _cachedTodos;

          final slivers = <Widget>[
            SliverToBoxAdapter(
              child: _FilterChips(selected: _filter, onSelected: _setFilter),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
          ];

          if (snapshot.hasError) {
            debugPrint('[TodoScreen] Error loading todos: ${snapshot.error}');
            slivers.add(SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.error_outline_rounded,
                title: l10n.todosLoadError,
                message: l10n.commonTryAgainLater,
              ),
            ));
          } else if (all == null) {
            slivers.add(const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
            ));
          } else {
            final notes = filterTodoNotes(all, _filter);
            if (notes.isEmpty) {
              slivers.add(SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.check_rounded,
                  title: switch (_filter) {
                    'pending' => l10n.todosNonePending,
                    'completed' => l10n.todosNoneCompleted,
                    _ => l10n.lsTodoEmpty,
                  },
                ),
              ));
            } else {
              slivers.add(SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: SketchSpace.screenX),
                sliver: SliverList.separated(
                  itemCount: notes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 22),
                  itemBuilder: (context, i) => TodoGroup(
                    key: ValueKey(notes[i].note.id),
                    note: notes[i],
                    onOpen: () => _open(notes[i]),
                    onToggle: _toggle,
                  ),
                ),
              ));
            }
          }

          slivers.add(SliverToBoxAdapter(
            child: SizedBox(height: dockAwareBottomPadding(context)),
          ));
          return CustomScrollView(slivers: slivers);
        },
      ),
    );
  }

  /// Notes for the All / Pending / Completed chips.
  @visibleForTesting
  static List<NoteWithDetails> filterTodoNotes(
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

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final chips = {
      'all': l10n.lsChipAll,
      'pending': l10n.todosPending,
      'completed': l10n.todosCompleted,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SketchSpace.screenX, 18, SketchSpace.screenX, 0),
      child: Wrap(
        spacing: SketchSpace.chip,
        runSpacing: SketchSpace.chip,
        children: [
          for (final e in chips.entries)
            SketchChip(
              label: e.value,
              selected: e.key == selected,
              onTap: () => onSelected(e.key),
            ),
        ],
      ),
    );
  }
}

/// One checklist on the Todo tab: a compact progress card with the note's
/// title, then its items (open first, then done).
class TodoGroup extends StatelessWidget {
  const TodoGroup({
    super.key,
    required this.note,
    required this.onOpen,
    required this.onToggle,
  });

  final NoteWithDetails note;
  final VoidCallback onOpen;
  final Future<void> Function(NoteTodoItem item, bool done) onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final items = note.todoItems;
    final done = items.where((i) => i.isDone).length;
    final ordered = [
      ...items.where((i) => !i.isDone),
      ...items.where((i) => i.isDone),
    ];
    final title = getNoteTitleOrPreview(note.note.noteTitle, note.textContent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProgressCard(
          compact: true,
          done: done,
          total: items.length,
          label: title.trim().isEmpty ? l10n.dsChecklist : title,
          summary: l10n.lsTodoSummary(done, items.length),
          pastel: NoteSwatch.resolve(note.color)?.color ?? SketchPastels.mint,
          onTap: onOpen,
        ),
        for (final item in ordered) ...[
          const SizedBox(height: 8),
          ChecklistRow(
            key: ValueKey(item.id),
            label: item.todoTitle,
            checked: item.isDone,
            // SketchCheckbox gives the light haptic itself.
            onChanged: (v) => onToggle(item, v),
          ),
        ],
      ],
    );
  }
}
