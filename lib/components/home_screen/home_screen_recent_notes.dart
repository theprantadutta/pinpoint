import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinpoint/components/shared/empty_state_widget.dart';
import 'package:pinpoint/screens/create_note_screen.dart';

import '../../design/app_theme.dart';
import '../../models/note_with_details.dart';
import '../../services/drift_note_service.dart';
import '../../screens/create_note_screen.dart' show CreateNoteScreen;

class HomeScreenRecentNotes extends StatelessWidget {
  final String searchQuery;
  const HomeScreenRecentNotes({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
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
                    color:
                        (dark ? Colors.white : Colors.black).withOpacity(0.06),
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
            // Content (single-column list)
            Expanded(
              child: StreamBuilder<List<NoteWithDetails>>(
                stream: DriftNoteService.watchNotesWithDetails(searchQuery),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: EmptyStateWidget(
                        message: 'Something went wrong',
                        iconData: Icons.error_outline,
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const EmptyStateWidget(
                      message: 'No notes yet. Create your first note!',
                      iconData: Icons.note_add,
                    );
                  }

                  final data = snapshot.data!;
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: data.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      return NoteListItem(note: data[i], showActions: true);
                    },
                  );
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
      child: InkWell(
        borderRadius: AppTheme.radiusL,
        onTap: () {
          Navigator.of(context).pushNamed(
            CreateNoteScreen.kRouteName,
            arguments: {
              'existingNote': note,
              'noticeType': n.defaultNoteType,
            },
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppTheme.radiusL,
            boxShadow: [
              // layered shadows for a more premium look
              BoxShadow(
                color: Colors.black.withOpacity(dark ? 0.30 : 0.10),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: cs.primary.withOpacity(dark ? 0.10 : 0.06),
                blurRadius: 36,
                spreadRadius: -6,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppTheme.radiusL,
            child: Stack(
              children: [
                // Gradient underlay
                Container(
                  decoration: const BoxDecoration(
                    borderRadius: AppTheme.radiusL,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0x1A7C3AED),
                        Color(0x1110B981),
                      ],
                    ),
                  ),
                ),
                // Subtle top highlight and bottom gradient footer
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: AppTheme.radiusL,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(dark ? 0.02 : 0.20),
                          Colors.transparent,
                          Colors.black.withOpacity(dark ? 0.25 : 0.06),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
                // Frosted glass body
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: (dark ? const Color(0xFF0F1218) : Colors.white)
                        .withOpacity(0.78),
                    borderRadius: AppTheme.radiusL,
                    border: Border.all(
                      color: (dark ? Colors.white : Colors.black)
                          .withOpacity(0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Leading: icon, live accent + pin tick
                      _LeadingBadge(
                        isPinned: n.isPinned,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 14),
                      // Title, snippet, meta
                      Expanded(
                        child: _TitleBlock(
                          title: n.noteTitle,
                          snippet: n.contentPlainText,
                          updatedAt: n.updatedAt,
                          folder: note.folders.isNotEmpty
                              ? note.folders.first.title
                              : null,
                          tag: note.tags.isNotEmpty
                              ? note.tags.first.tagTitle
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Trailing compact actions with pressed states
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MiniActionPro(
                            tooltip: n.isPinned ? 'Unpin' : 'Pin',
                            icon: n.isPinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            color: cs.primary,
                            onTap: () {
                              DriftNoteService.togglePinStatus(
                                  n.id, !n.isPinned);
                            },
                          ),
                          const SizedBox(width: 8),
                          _MiniActionPro(
                            tooltip: 'Archive',
                            icon: Icons.archive_outlined,
                            color: cs.secondary,
                            onTap: () {
                              DriftNoteService.toggleArchiveStatus(n.id, true);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
        borderRadius: AppTheme.radiusM,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(dark ? 0.22 : 0.16),
            color.withOpacity(dark ? 0.10 : 0.08),
          ],
        ),
        border: Border.all(
            color: (dark ? Colors.white : Colors.black).withOpacity(0.08)),
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
                    color:
                        (dark ? Colors.white : Colors.black).withOpacity(0.10),
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
  final String? folder;
  final String? tag;

  const _TitleBlock({
    required this.title,
    required this.snippet,
    required this.updatedAt,
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
            maxLines: 1,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withOpacity(0.80),
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
              color: widget.color.withOpacity(dark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (dark ? Colors.white : Colors.black).withOpacity(0.10),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(dark ? 0.28 : 0.10),
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

class _MiniAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(dark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: (dark ? Colors.white : Colors.black).withOpacity(0.10),
            ),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
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
        color: (dark ? Colors.white : Colors.black).withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (dark ? Colors.white : Colors.black).withOpacity(0.08),
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
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.86),
                ),
          ),
        ],
      ),
    );
  }
}
