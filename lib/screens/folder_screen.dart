import 'package:flutter/material.dart';
import 'package:pinpoint/components/shared/empty_state_widget.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/services/logger_service.dart';
import 'package:pinpoint/components/home_screen/home_screen_recent_notes.dart'
    show _RecentNoteListItem;

class FolderScreen extends StatelessWidget {
  static const String kRouteName = '/folder';
  final int folderId;
  final String folderTitle;

  Future<NoteFolder?> _fetchFolder(int id) async {
    try {
      final db = getIt<AppDatabase>();
      return (db.select(db.noteFolders)
            ..where((t) => t.noteFolderId.equals(id)))
          .getSingleOrNull();
    } catch (e, st) {
      log.e('[FolderScreen] failed to fetch folder by id=$id', e, st);
      return null;
    }
  }

  const FolderScreen({
    super.key,
    required this.folderId,
    required this.folderTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<NoteFolder?>(
          future: _fetchFolder(folderId),
          builder: (context, snap) {
            final title = snap.data?.noteFolderTitle ?? folderTitle;
            return Text(title);
          },
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<NoteWithDetails>>(
        stream: DriftNoteService.watchNotesWithDetailsByFolder(folderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
            Future<NoteFolder?> _fetchFolder(int id) async {
              try {
                final db = getIt<AppDatabase>();
                return (db.select(db.noteFolders)
                      ..where((t) => t.noteFolderId.equals(id)))
                    .getSingleOrNull();
              } catch (e, st) {
                log.e('[FolderScreen] failed to fetch folder by id=$id', e, st);
                return null;
                Future<NoteFolder?> _fetchFolder(int id) async {
                  try {
                    final db = getIt<AppDatabase>();
                    return (db.select(db.noteFolders)
                          ..where((t) => t.noteFolderId.equals(id)))
                        .getSingleOrNull();
                  } catch (e, st) {
                    log.e('[FolderScreen] failed to fetch folder by id=$id', e,
                        st);
                    return null;
                  }
                }
              }
              Future<NoteFolder?> _fetchFolder(int id) async {
                try {
                  final db = getIt<AppDatabase>();
                  return (db.select(db.noteFolders)
                        ..where((t) => t.noteFolderId.equals(id)))
                      .getSingleOrNull();
                } catch (e, st) {
                  log.e(
                      '[FolderScreen] failed to fetch folder by id=$id', e, st);
                  return null;
                }
              }
            }
          }
          final notes = snapshot.data ?? const <NoteWithDetails>[];
          if (notes.isEmpty) {
            return const EmptyStateWidget(
              message: 'No notes in this folder yet.',
              iconData: Icons.folder_open,
            );
          }
          // Single-column, full-width list similar to Home's Recent Notes
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
              itemCount: notes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                // Inline lightweight list item to avoid private symbol import issues
                final nwd = notes[index];
                return Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF0F1218).withOpacity(0.78)
                      : Colors.white.withOpacity(0.78),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black)
                          .withOpacity(0.06),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      // Reuse existing note open flow: Create screen via route args used in NoteGridItem/Home list
                      Navigator.of(context).pushNamed(
                        '/create',
                        arguments: {
                          'existingNote': nwd,
                          'noticeType': nwd.note.defaultNoteType,
                        },
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.16),
                                  Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.08),
                                ],
                              ),
                              border: Border.all(
                                color: (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black)
                                    .withOpacity(0.08),
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.description_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((nwd.note.noteTitle ?? '').isNotEmpty)
                                  Text(
                                    nwd.note.noteTitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.1,
                                        ),
                                  ),
                                if ((nwd.note.contentPlainText ?? '')
                                    .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      nwd.note.contentPlainText!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.80),
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
