import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material_ui;
import 'package:pinpoint/components/shared/note_grid.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/design_system/design_system.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/models/folder_summary.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/screens/my_folders_screen.dart';
import 'package:pinpoint/screens/todo_screen.dart';
import 'package:pinpoint/screens/trash_screen.dart';
import 'package:pinpoint/services/locale_controller.dart';
import 'package:pinpoint/widgets/pinpoint_popup_menu_button.dart';

import 'support/sketch_harness.dart';

/// Widget + golden coverage for the folders and secondary screens (My
/// folders grid and free-limit banner, the Trash banner and grid, the popup
/// menu). Regenerate with
/// `flutter test --update-goldens test/folders_secondary_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadSketchFonts);

  /// A full-bleed themed page (no harness padding), so screens render as on
  /// a phone.
  Widget page(Widget child, Brightness b) => MaterialApp(
        key: ValueKey(b),
        debugShowCheckedModeBanner: false,
        theme: PinpointTheme.light(),
        darkTheme: PinpointTheme.dark(),
        themeMode: b == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('en'),
        supportedLocales: LocaleController.supportedLocales,
        localizationsDelegates: const [
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          ...material_ui.GlobalMaterialLocalizations.delegates,
        ],
        home: child,
      );

  Future<void> golden(
    WidgetTester tester,
    String name,
    Widget Function() build, {
    Size size = const Size(390, 844),
    Future<void> Function()? after,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    for (final b in Brightness.values) {
      await tester.pumpWidget(page(build(), b));
      await tester.pumpAndSettle();
      if (after != null) await after();
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/${name}_${b.name}.png'),
      );
    }
  }

  final t0 = DateTime(2026, 9, 1);
  NoteFolder folder(int id, String title, {String? color}) => NoteFolder(
        noteFolderId: id,
        uuid: 'f$id',
        noteFolderTitle: title,
        createdAt: t0.add(Duration(minutes: id)),
        updatedAt: t0,
        color: color,
      );
  FolderNotePreview preview(int id, Color c) =>
      FolderNotePreview(noteId: id, type: 'text', title: 'N$id', color: c);

  final folders = [
    FolderSummary(
      folder: folder(1, 'Random', color: 'yellow'),
      color: SketchPastels.yellow,
      noteCount: 5,
      voiceCount: 0,
      recent: [
        preview(1, SketchPastels.mint),
        preview(2, SketchPastels.lavender),
        preview(3, SketchPastels.sky),
      ],
    ),
    FolderSummary(
      folder: folder(2, 'HomeWork', color: 'lavender'),
      color: SketchPastels.lavender,
      noteCount: 3,
      voiceCount: 0,
      recent: [
        preview(4, SketchPastels.yellow),
        preview(5, SketchPastels.pink),
      ],
    ),
    FolderSummary(
      folder: folder(3, 'Workout', color: 'mint'),
      color: SketchPastels.mint,
      noteCount: 2,
      voiceCount: 1,
      recent: [
        preview(6, SketchPastels.lavender),
        preview(7, SketchPastels.yellow),
      ],
    ),
    FolderSummary(
      folder: folder(4, 'Office', color: 'sky'),
      color: SketchPastels.sky,
      noteCount: 1,
      voiceCount: 0,
      recent: [preview(8, SketchPastels.mint)],
    ),
    FolderSummary(
      folder: folder(5, 'Sports', color: 'pink'),
      color: SketchPastels.pink,
      noteCount: 1,
      voiceCount: 0,
      recent: [preview(9, SketchPastels.sky)],
    ),
  ];

  Widget myFolders() => Builder(builder: (context) {
        final l10n = AppL10n.of(context);
        return SketchScaffold(
          largeTitle: true,
          title: l10n.foldersMyFolders,
          subtitle: l10n.flSubtitle,
          doodleTop: DoodleBackground.foldersTop,
          squiggle: true,
          actions: [
            CircleIconButton(
              icon: Icons.add_rounded,
              iconSize: 24,
              fill: context.sketch.inverse,
              semanticLabel: l10n.foldersCreate,
              onPressed: () {},
            ),
          ],
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: FolderGrid(folders: folders, onCreate: () {}),
          ),
          bottom: UpgradeBanner(
            title: l10n.flFreeLimitTitle(5, 5),
            message: l10n.flFreeLimitBody,
            actionLabel: l10n.usageUpgrade,
            onAction: () {},
          ),
        );
      });

  testWidgets('my folders: folder grid with the free-limit banner',
      (tester) async {
    await golden(tester, 'my_folders', myFolders);
    expect(find.text('Random'), findsOneWidget);
    expect(find.text('2 notes · 1 voice'), findsOneWidget);
    expect(find.text('5 of 5 free folders used'), findsOneWidget);
    expect(find.text('New folder'), findsOneWidget);
  });

  test('free-limit banner shows for free users at 4 or more folders', () {
    expect(FolderLimitBanner.shouldShow(isPremium: false, count: 3), isFalse);
    expect(FolderLimitBanner.shouldShow(isPremium: false, count: 4), isTrue);
    expect(FolderLimitBanner.shouldShow(isPremium: false, count: 5), isTrue);
    expect(FolderLimitBanner.shouldShow(isPremium: true, count: 5), isFalse);
  });

  testWidgets('folder grid: create, long-press and accessible reorder',
      (tester) async {
    var created = 0;
    var longPressed = 0;
    final moves = <(int, int)>[];
    var drops = 0;

    Widget grid({required bool reordering}) => sketchApp(
          SingleChildScrollView(
            child: FolderGrid(
              folders: folders.take(3).toList(),
              reordering: reordering,
              onCreate: () => created++,
              onLongPress: () => longPressed++,
              onMove: (id, i) => moves.add((id, i)),
              onDropped: () => drops++,
            ),
          ),
        );

    await tester.pumpWidget(grid(reordering: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New folder'));
    expect(created, 1);
    await tester.longPress(find.text('HomeWork'));
    expect(longPressed, 1);

    // Reorder mode: no New folder tile, and screen readers get move actions.
    await tester.pumpWidget(grid(reordering: true));
    await tester.pumpAndSettle();
    expect(find.text('New folder'), findsNothing);

    Map<CustomSemanticsAction, VoidCallback> actionsOf(String title) => tester
        .widget<Semantics>(find
            .ancestor(
              of: find.text(title),
              matching: find.byWidgetPredicate((w) =>
                  w is Semantics &&
                  w.properties.customSemanticsActions != null),
            )
            .first)
        .properties
        .customSemanticsActions!;

    final first = actionsOf('Random');
    expect(first.keys.map((a) => a.label), ['Move later']);
    expect(actionsOf('HomeWork').keys.map((a) => a.label),
        ['Move earlier', 'Move later']);

    first.entries.single.value();
    expect(moves, [(1, 1)]);
    expect(drops, 1);
  });

  NoteWithDetails note(int id, String title, String body,
          {String type = 'text', String? color}) =>
      NoteWithDetails(
        note: Note(
          id: id,
          uuid: 'n$id',
          noteType: type,
          noteTitle: title,
          isPinned: false,
          isArchived: false,
          isDeleted: true,
          isSynced: true,
          createdAt: t0,
          updatedAt: DateTime.now().subtract(Duration(days: id)),
        ),
        folders: const [],
        attachments: const [],
        todoItems: const [],
        textContent: body,
        color: color,
      );

  testWidgets('trash: banner with Empty trash and dimmed cards',
      (tester) async {
    final notes = [
      note(1, 'Groceries', 'Milk, eggs and bread', color: 'yellow'),
      note(2, 'Old idea', 'Something about a garden\nand a shed'),
      note(3, 'Call list', 'Mum\nDentist'),
    ];
    await golden(
      tester,
      'trash',
      () => Builder(builder: (context) {
        final l10n = AppL10n.of(context);
        return SketchScaffold(
          title: l10n.trashTitle,
          // Swooshes behind the header only: they would show through the
          // dimmed cards.
          doodleTop: -60,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: TrashBanner(
                    message: l10n.lsTrashKeep,
                    actionLabel: l10n.lsEmptyTrash,
                    onAction: () {},
                  ),
                ),
              ),
              NoteGridSliver(
                notes: notes,
                itemBuilder: (context, n) => ManagedNoteItem(
                  note: n,
                  isTrashView: true,
                  caption:
                      l10n.trashDeletedAgo(l10n.relativeTimeDaysAgo(n.note.id)),
                  actions: [
                    NoteAction(
                      icon: Icons.restore_from_trash_outlined,
                      label: l10n.lsRestoreNote(n.note.noteTitle!),
                      onTap: () async {},
                    ),
                    NoteAction(
                      icon: Icons.delete_forever_outlined,
                      label: l10n.lsDeleteNoteForever(n.note.noteTitle!),
                      destructive: true,
                      onTap: () async {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
      size: const Size(390, 640),
    );
    expect(
        find.text('Notes stay in trash until you empty it.'), findsOneWidget);
    expect(find.text('Empty trash'), findsOneWidget);
  });

  testWidgets('trash banner hides Empty trash when there is nothing to empty',
      (tester) async {
    await tester.pumpWidget(sketchApp(const TrashBanner(
      message: 'Notes stay in trash until you empty it.',
      actionLabel: 'Empty trash',
      onAction: null,
    )));
    expect(find.text('Empty trash'), findsNothing);
  });

  testWidgets('popup menu: outlined surface, 44px rows and hairlines',
      (tester) async {
    final menu = Builder(builder: (context) {
      final l10n = AppL10n.of(context);
      return Scaffold(
        body: Align(
          alignment: const Alignment(0.6, -0.8),
          child: PinpointPopupMenuButton<String>(
            tooltip: l10n.flMenuLabel('Work'),
            itemBuilder: (ctx) => [
              PinpointPopupMenuButton.item(ctx,
                  value: 'rename',
                  label: l10n.foldersRename,
                  icon: Icons.drive_file_rename_outline_rounded),
              PinpointPopupMenuButton.item(ctx,
                  value: 'colour',
                  label: l10n.flChangeColour,
                  icon: Icons.palette_outlined),
              PinpointPopupMenuButton.item(ctx,
                  value: 'delete',
                  label: l10n.commonDelete,
                  icon: Icons.delete_outline_rounded,
                  destructive: true),
            ],
          ),
        ),
      );
    });

    await golden(
      tester,
      'popup_menu',
      () => menu,
      size: const Size(390, 360),
      after: () async {
        await tester.tap(find.byIcon(Icons.more_horiz_rounded));
        await tester.pumpAndSettle();
      },
    );
    // Three rows, two hairlines between them.
    expect(find.byType(PopupMenuDivider), findsNWidgets(2));
    expect(
      tester.getSize(find.byType(PopupMenuItem<String>).first).height,
      SketchSpace.minTap,
    );
  });

  test('todo filters: pending keeps open lists, completed only finished ones',
      () {
    NoteWithDetails todo(int id, List<bool> done) => NoteWithDetails(
          note: Note(
            id: id,
            uuid: 't$id',
            noteType: 'todo',
            noteTitle: 'List $id',
            isPinned: false,
            isArchived: false,
            isDeleted: false,
            isSynced: true,
            createdAt: t0,
            updatedAt: t0,
          ),
          folders: const [],
          attachments: const [],
          todoItems: [
            for (var i = 0; i < done.length; i++)
              NoteTodoItem(
                id: id * 10 + i,
                uuid: 'i$id$i',
                noteId: id,
                noteUuid: 't$id',
                todoTitle: 'Item $i',
                isDone: done[i],
                orderIndex: i,
              ),
          ],
        );
    final notes = [
      todo(1, [true, false]),
      todo(2, [true, true]),
      todo(3, []),
    ];
    List<int> ids(String f) =>
        filterTodoNotes(notes, f).map((n) => n.note.id).toList();
    expect(ids('all'), [1, 2, 3]);
    expect(ids('pending'), [1, 3]);
    expect(ids('completed'), [2]);
  });
}
