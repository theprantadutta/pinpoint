import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/constants/shared_preference_keys.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/screens/create_note_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design_system/design_system.dart';
import '../../models/note_with_details.dart';
import '../../services/drift_note_service.dart';
import '../../screens/create_note_screen.dart' show CreateNoteScreen;

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
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _viewType = _prefs?.getString(kHomeScreenViewTypeKey) ?? 'list';
      _sortType = _prefs?.getString(kHomeScreenSortTypeKey) ?? 'updatedAt';
      _sortDirection = _prefs?.getString(kHomeScreenSortDirectionKey) ?? 'desc';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Padding(
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
              child: StreamBuilder<List<NoteWithDetails>>(
                stream: DriftNoteService.watchNotesWithDetails(
                    widget.searchQuery, _sortType, _sortDirection),
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
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      itemCount: data.length,
                      itemBuilder: (context, i) {
                        return NoteListItem(note: data[i], showActions: true);
                      },
                    );
                  } else {
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: data.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        return NoteListItem(note: data[i], showActions: true);
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
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
    final dark = theme.brightness == Brightness.dark;
    final n = note.note;

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
        title: n.noteTitle ?? 'Untitled',
        excerpt: n.contentPlainText,
        lastModified: n.updatedAt,
        isPinned: n.isPinned,
        tags: [
          if (note.folders.isNotEmpty)
            CardNoteTag(
              label: note.folders.first.title,
              color: cs.primary,
            ),
          ...note.tags.take(2).map(
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
              noticeType: n.defaultNoteType,
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

class _LeadingBadge extends StatelessWidget {
  final bool isPinned;
  final Color color;
  const _LeadingBadge({required this.isPinned, required this.color});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withAlpha(dark ? 56 : 40),
            color.withAlpha(dark ? 25 : 20),
          ],
        ),
        border: Border.all(
            color: (dark ? Colors.white : Colors.black).withAlpha(20)),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(Icons.description_rounded, color: color, size: 22),
          ),
          if (isPinned)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (dark ? Colors.white : Colors.black).withAlpha(25),
                  ),
                ),
                child:
                    const Icon(Icons.push_pin, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  final String? title;
  final String? snippet;
  final DateTime updatedAt;
  final DateTime? reminderTime;
  final String? folder;
  final String? tag;

  const _TitleBlock({
    required this.title,
    required this.snippet,
    required this.updatedAt,
    this.reminderTime,
    this.folder,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((title ?? '').isNotEmpty)
          Text(
            title!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
        if ((snippet ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(
              snippet!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withAlpha(200),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            _MetaPill(
              icon: Icons.access_time,
              label: _formatRelative(updatedAt),
              color: cs.secondary,
            ),
            if (folder != null)
              _MetaPill(
                icon: Icons.folder_open,
                label: folder!,
                color: cs.primary,
              ),
            if (tag != null)
              _MetaPill(
                icon: Icons.sell_outlined,
                label: tag!,
                color: cs.primary,
              ),
            if (reminderTime != null)
              _MetaPill(
                icon: Icons.alarm,
                label: _formatRelative(reminderTime!),
                color: cs.primary,
              ),
          ],
        ),
      ],
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

String _formatRelative(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (dark ? Colors.white : Colors.black).withAlpha(15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (dark ? Colors.white : Colors.black).withAlpha(20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(220),
                ),
          ),
        ],
      ),
    );
  }
}
