import 'package:flutter/material.dart';
import 'package:pinpoint/components/shared/empty_state_widget.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/services/drift_note_service.dart';

class TrashScreen extends StatelessWidget {
  static const String kRouteName = '/trash';

  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Trash'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<NoteWithDetails>>(
        stream: DriftNoteService.watchDeletedNotes(),
        builder: (context, snapshot) {
          final waiting = snapshot.connectionState == ConnectionState.waiting;
          if (waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: EmptyStateWidget(
                message: 'Could not load trash.\n${snapshot.error}',
                iconData: Icons.error_outline,
              ),
            );
          }

          final notes = snapshot.data ?? const <NoteWithDetails>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                child: Row(
                  children: [
                    Text(
                      'Trash',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.error.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: cs.error.withOpacity(0.22),
                        ),
                      ),
                      child: Text(
                        '${notes.length}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: cs.error,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.error.withOpacity(0.22),
                        cs.error.withOpacity(0.0),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Content
              Expanded(
                child: notes.isEmpty
                    ? const Center(
                        child: EmptyStateWidget(
                          message:
                              'Trash is empty.\nDeleted notes will appear here temporarily.',
                          iconData: Icons.delete_outline,
                        ),
                      )
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: ListView.separated(
                          key: ValueKey(notes.length),
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          itemCount: notes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final n = notes[index].note;
                            final note = notes[index];
                            final theme = Theme.of(context);
                            final cs = theme.colorScheme;
                            final dark = theme.brightness == Brightness.dark;

                            return InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                Navigator.of(context).pushNamed(
                                  '/create',
                                  arguments: {
                                    'existingNote': note,
                                    'noticeType': n.defaultNoteType,
                                  },
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: (dark
                                          ? const Color(0xFF0F1218)
                                          : Colors.white)
                                      .withOpacity(0.78),
                                  border: Border.all(
                                    color: (dark ? Colors.white : Colors.black)
                                        .withOpacity(0.06),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withOpacity(dark ? 0.26 : 0.08),
                                      blurRadius: 18,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    // Leading badge
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            cs.primary.withOpacity(
                                                dark ? 0.22 : 0.16),
                                            cs.primary.withOpacity(
                                                dark ? 0.10 : 0.08),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: (dark
                                                  ? Colors.white
                                                  : Colors.black)
                                              .withOpacity(0.08),
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.description_rounded,
                                          color: cs.primary,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Title + snippet
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if ((n.noteTitle ?? '').isNotEmpty)
                                            Text(
                                              n.noteTitle!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.1,
                                              ),
                                            ),
                                          if ((n.contentPlainText ?? '')
                                              .isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 2.0),
                                              child: Text(
                                                n.contentPlainText!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme
                                                    .textTheme.bodyMedium
                                                    ?.copyWith(
                                                  color: cs.onSurface
                                                      .withOpacity(0.80),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Trailing actions for trash
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Restore',
                                          icon: const Icon(
                                              Icons.restore_from_trash),
                                          color: cs.primary,
                                          onPressed: () async {
                                            await DriftNoteService
                                                .restoreNoteById(n.id);
                                          },
                                        ),
                                        IconButton(
                                          tooltip: 'Delete forever',
                                          icon:
                                              const Icon(Icons.delete_forever),
                                          color: cs.error,
                                          onPressed: () async {
                                            final confirmed =
                                                await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text(
                                                    'Delete permanently?'),
                                                content: const Text(
                                                    'This action cannot be undone. The note and its attachments will be removed forever.'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(ctx)
                                                            .pop(false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  FilledButton.tonal(
                                                    onPressed: () =>
                                                        Navigator.of(ctx)
                                                            .pop(true),
                                                    child: const Text(
                                                        'Delete forever'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirmed == true) {
                                              await DriftNoteService
                                                  .permanentlyDeleteNoteById(
                                                      n.id);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
