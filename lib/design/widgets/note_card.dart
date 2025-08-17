import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../design/app_theme.dart';

class NoteCard extends StatelessWidget {
  final String? title;
  final String? preview;
  final bool pinned;
  final DateTime updatedAt;
  final DateTime? reminderTime;
  final List<String> tags;
  final VoidCallback? onTap;

  const NoteCard({
    super.key,
    required this.title,
    required this.preview,
    required this.pinned,
    required this.updatedAt,
    this.reminderTime,
    this.tags = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context);
    final cs = text.colorScheme;
    final dark = text.brightness == Brightness.dark;

    return Hero(
      tag: 'note_${hashCode}_hero',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.radiusL,
          splashColor: cs.primary.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: AppTheme.radiusL,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(dark ? 70 : 25),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: cs.primary.withAlpha(dark ? 25 : 15),
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
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: AppTheme.radiusL,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withAlpha(dark ? 5 : 50),
                            Colors.transparent,
                            Colors.black.withAlpha(dark ? 60 : 15),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (dark ? const Color(0xFF0F1218) : Colors.white)
                          .withAlpha(200),
                      borderRadius: AppTheme.radiusL,
                      border: Border.all(
                        color: (dark ? Colors.white : Colors.black).withAlpha(15),
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title?.isNotEmpty == true ? title! : 'Untitled',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                ),
                                if (pinned)
                                  Icon(Icons.push_pin_rounded,
                                      size: 18,
                                      color: cs.primary),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (preview?.isNotEmpty == true)
                              Text(
                                preview!,
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                style: text.textTheme.bodyMedium?.copyWith(height: 1.28),
                              ),
                            if (reminderTime != null) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.alarm,
                                      size: 14, color: cs.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat('MMM d, yyyy hh:mm a').format(reminderTime!),
                                    style: text.textTheme.labelMedium?.copyWith(
                                        color: cs.primary),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.schedule_rounded,
                                    size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 6),
                                Text(
                                  _friendlyTime(updatedAt),
                                  style: text.textTheme.labelMedium
                                      ?.copyWith(color: Colors.grey.shade600),
                                ),
                                const Spacer(),
                                ...tags.take(2).map(
                                      (t) => Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: Chip(
                                          label: Text(t),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                              ],
                            )
                          ],
                        );
                      }
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _friendlyTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }
}