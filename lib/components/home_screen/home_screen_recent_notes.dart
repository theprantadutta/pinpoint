import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/constants/shared_preference_keys.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/screens/create_note_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design_system/design_system.dart';
import '../../models/note_with_details.dart';
import '../../services/drift_note_service.dart';
import '../../services/filter_service.dart';
import '../../screens/create_note_screen.dart' show CreateNoteScreen;
import '../../util/note_utils.dart';

class HomeScreenRecentNotes extends StatefulWidget {
  final String searchQuery;
  final ScrollController? scrollController;

  const HomeScreenRecentNotes({
    super.key,
    required this.searchQuery,
    this.scrollController,
  });

  @override
  State<HomeScreenRecentNotes> createState() => _HomeScreenRecentNotesState();
}

class _HomeScreenRecentNotesState extends State<HomeScreenRecentNotes> {
  String _viewType = 'list';
  String _sortType = 'updatedAt';
  String _sortDirection = 'desc';
  SharedPreferences? _preferences;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _preferences = await SharedPreferences.getInstance();
    setState(() {
      _viewType = _preferences?.getString(kHomeScreenViewTypeKey) ?? 'list';
      _sortType =
          _preferences?.getString(kHomeScreenSortTypeKey) ?? 'updatedAt';
      _sortDirection =
          _preferences?.getString(kHomeScreenSortDirectionKey) ?? 'desc';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Recent notes',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (dark ? Colors.white : Colors.black)
                        .withAlpha(dark ? 15 : 20),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Live',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Content
            Expanded(
              child: Consumer<FilterService>(
                builder: (context, filterService, _) {
                  return StreamBuilder<List<NoteWithDetails>>(
                    stream: DriftNoteService.watchNotesWithDetails(
                      searchQuery: widget.searchQuery,
                      sortType: _sortType,
                      sortDirection: _sortDirection,
                      filterOptions: filterService.filterOptions,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                    return EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: 'Something went wrong',
                      message: 'Please try again later',
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return EmptyState(
                      icon: Icons.note_add_rounded,
                      title: 'No notes yet',
                      message: 'Create your first note to get started',
                    );
                  }

                  final data = snapshot.data!;

                  if (_viewType == 'grid') {
                    return MasonryGridView.count(
                      controller: widget.scrollController,
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: data.length,
                      itemBuilder: (context, i) {
                        return NoteListItem(note: data[i], showActions: true);
                      },
                    );
                  } else {
                    return ListView.separated(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.only(top: 8, bottom: 100),
                      itemCount: data.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        return NoteListItem(note: data[i], showActions: true);
                      },
                    );
                  }
                },
              );
                },
              ),
            ),
          ],
        ),
    );
  }
}

class NoteListItem extends StatelessWidget {
  final NoteWithDetails note;
  final bool isArchivedView;
  final bool isTrashView;
  final bool showActions;

  const NoteListItem({
    super.key,
    required this.note,
    this.isArchivedView = false,
    this.isTrashView = false,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final n = note.note;
    final hasTitle = n.noteTitle != null && n.noteTitle!.trim().isNotEmpty;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.98, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) => AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: 1.0,
        child: Transform.scale(scale: scale, child: child),
      ),
      child: NoteCard(
        title: getNoteTitleOrPreview(n.noteTitle, note.textContent),
        excerpt: hasTitle ? note.textContent : null,
        lastModified: n.updatedAt,
        isPinned: n.isPinned,
        tags: [
          if (note.folders.isNotEmpty)
            CardNoteTag(
              label: note.folders.first.title,
              color: cs.primary,
            ),
        ],
        onTap: () {
          PinpointHaptics.medium();
          context.push(
            CreateNoteScreen.kRouteName,
            extra: CreateNoteScreenArguments(
              noticeType: n.noteType,
              existingNote: note,
            ),
          );
        },
        onPinToggle: () {
          PinpointHaptics.light();
          DriftNoteService.togglePinStatus(n.id, !n.isPinned);
        },
      ),
    );
  }
}


class _MiniActionPro extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniActionPro({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_MiniActionPro> createState() => _MiniActionProState();
}

class _MiniActionProState extends State<_MiniActionPro>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.color.withAlpha(dark ? 30 : 20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (dark ? Colors.white : Colors.black).withAlpha(25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(dark ? 70 : 25),
                  blurRadius: _pressed ? 6 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(widget.icon, size: 18, color: widget.color),
          ),
        ),
      ),
    );
  }
}

