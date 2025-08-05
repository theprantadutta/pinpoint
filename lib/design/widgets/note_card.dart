import 'package:flutter/material.dart';
import '../../design/app_theme.dart';

class NoteCard extends StatelessWidget {
  final String? title;
  final String? preview;
  final bool pinned;
  final DateTime updatedAt;
  final List<String> tags;
  final VoidCallback? onTap;

  const NoteCard({
    super.key,
    required this.title,
    required this.preview,
    required this.pinned,
    required this.updatedAt,
    this.tags = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Hero(
      tag: 'note_${hashCode}_hero',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.radiusL,
          splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: AppTheme.radiusL,
              color: (dark ? const Color(0xFF12151C) : Colors.white)
                  .withOpacity(0.78),
              boxShadow: AppTheme.shadowSoft(dark),
              border: Border.all(
                color: (dark ? Colors.white : Colors.black).withOpacity(0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title?.isNotEmpty == true ? title! : 'Untitled',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    if (pinned)
                      Icon(Icons.push_pin_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary),
                  ],
                ),
                const SizedBox(height: 10),
                if (preview?.isNotEmpty == true)
                  Text(
                    preview!,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(height: 1.28),
                  ),
                const Spacer(),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      _friendlyTime(updatedAt),
                      style: text.labelMedium
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
