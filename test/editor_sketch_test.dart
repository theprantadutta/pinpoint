import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material_ui;
import 'package:pinpoint/components/create_note_screen/editor_chrome.dart';
import 'package:pinpoint/components/create_note_screen/record_audio_type/voice_fab.dart';
import 'package:pinpoint/components/create_note_screen/todo_list_type/checklist_add_bar.dart';
import 'package:pinpoint/components/create_note_screen/todo_list_type/checklist_editor.dart';
import 'package:pinpoint/design_system/design_system.dart';
import 'package:pinpoint/dtos/note_folder_dto.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/services/locale_controller.dart';
import 'package:pinpoint/widgets/markdown_editor.dart';
import 'package:pinpoint/widgets/markdown_toolbar.dart';

import 'support/sketch_harness.dart';

/// Widget + golden coverage for the Sketchbook note editor (SCREENS.md §04)
/// and checklist note (§05), light and dark. Regenerate the goldens with
/// `flutter test --update-goldens test/editor_sketch_test.dart` after an
/// intentional visual change.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadSketchFonts);

  /// A full-bleed app (no harness padding) for screen-shaped goldens.
  Widget screenApp(Widget child, Brightness brightness) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: PinpointTheme.light(),
      darkTheme: PinpointTheme.dark(),
      themeMode:
          brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
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
  }

  Future<void> golden(
    WidgetTester tester,
    String name,
    Widget Function() build, {
    Size size = const Size(390, 844),
    bool fullBleed = true,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    for (final b in Brightness.values) {
      await tester.pumpWidget(fullBleed
          ? screenApp(build(), b)
          : sketchApp(build(), brightness: b));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/${name}_${b.name}.png'),
      );
    }
  }

  /// "Some bold text" with the caret inside "bold", so B shows as active.
  FleatherController boldController() {
    final doc = ParchmentDocument.fromJson([
      {'insert': 'Some '},
      {
        'insert': 'bold',
        'attributes': {'b': true}
      },
      {'insert': ' text\n'},
    ]);
    return FleatherController(document: doc)
      ..updateSelection(const TextSelection.collapsed(offset: 7));
  }

  /// The mock's body: a paragraph with bold, italic and a highlight, an H3
  /// and two bullets.
  FleatherController sampleBody() {
    final hl = MarkdownToolbar.highlightBackground;
    final ink = MarkdownToolbar.highlightForeground;
    return FleatherController(
      document: ParchmentDocument.fromJson([
        {'insert': 'Some letters are '},
        {
          'insert': 'bold',
          'attributes': {'b': true}
        },
        {'insert': ' and some are '},
        {
          'insert': 'italic',
          'attributes': {'i': true}
        },
        {'insert': ' and '},
        {
          'insert': 'some',
          'attributes': {'bg': hl, 'fg': ink}
        },
        {'insert': ' are '},
        {
          'insert': 'both',
          'attributes': {'b': true, 'i': true}
        },
        {'insert': '.\nKey points'},
        {
          'insert': '\n',
          'attributes': {'heading': 3}
        },
        {'insert': "Progress is often invisible while you're making it."},
        {
          'insert': '\n',
          'attributes': {'block': 'ul'}
        },
        {'insert': 'Most projects look like a mess until they work.'},
        {
          'insert': '\n',
          'attributes': {'block': 'ul'}
        },
      ]),
    );
  }

  const groceries = [
    ChecklistEntry(id: 1, text: 'Buy Milk', done: false),
    ChecklistEntry(id: 2, text: 'Eggs, a dozen', done: false),
    ChecklistEntry(id: 3, text: 'Bread', done: true),
    ChecklistEntry(id: 4, text: 'Coffee beans', done: true),
  ];

  /// The editor chrome without the database-backed screen State.
  Widget editorFrame({
    required Widget body,
    required String title,
    Widget? floating,
    bool pin = true,
    double doodleTop = DoodleBackground.editorTop,
  }) {
    return Builder(builder: (context) {
      final titleController = TextEditingController(text: title);
      return Scaffold(
        backgroundColor: context.sketch.bg,
        body: DoodleBackground(
          top: doodleTop,
          squiggle: pin,
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    EditorTopBar(
                      onBack: () {},
                      folderChip: EditorFolderChip(
                        folders: [NoteFolderDto(id: 1, title: 'Random')],
                        colors: const {1: SketchPastels.yellow},
                        onTap: () {},
                      ),
                      pin: pin
                          ? EditorPinButton(pinned: true, onPressed: () {})
                          : null,
                      menu: CircleIconButton(
                        icon: Icons.more_horiz_rounded,
                        iconSize: 22,
                        semanticLabel: 'More options',
                        onPressed: () {},
                      ),
                    ),
                    Expanded(
                      child: CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
                            sliver: SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  EditorTitleField(
                                    controller: titleController,
                                    focusNode: FocusNode(),
                                  ),
                                  const SizedBox(height: 2),
                                  EditorMetaRow(
                                    editedAt: DateTime(2026, 10, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          body,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (floating != null) floating,
            ],
          ),
        ),
      );
    });
  }

  group('goldens', () {
    testWidgets('editor toolbar', (tester) async {
      await golden(
        tester,
        'editor_toolbar',
        () => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MarkdownToolbar(
              controller: boldController(),
              onColorPressed: () {},
              onImagePressed: () {},
            ),
            const SizedBox(height: 16),
            MarkdownToolbar(
              controller: boldController(),
              noteColor: SketchPastels.mint,
              onColorPressed: () {},
              onImagePressed: () {},
            ),
          ],
        ),
        size: const Size(390, 220),
        fullBleed: false,
      );
    });

    testWidgets('note editor in context', (tester) async {
      await golden(
        tester,
        'note_editor',
        () => editorFrame(
          title: 'New Note',
          body: SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            sliver: SliverToBoxAdapter(
              child: MarkdownEditor(controller: sampleBody()),
            ),
          ),
          floating: Stack(
            children: [
              PositionedDirectional(
                end: VoiceFab.end - 10,
                bottom: VoiceFab.bottom - 10,
                child: VoiceFab(
                  recording: false,
                  elapsed: Duration.zero,
                  semanticLabel: 'New voice note',
                  onPressed: () {},
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: EditorToolbarDock(
                  child: MarkdownToolbar(
                    controller: boldController(),
                    onColorPressed: () {},
                    onImagePressed: () {},
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });

    testWidgets('checklist rows in context', (tester) async {
      await golden(
        tester,
        'checklist_note',
        () => editorFrame(
          title: 'Groceries',
          pin: false,
          doodleTop: DoodleBackground.todoTop,
          body: ChecklistEditorSliver(
            items: groceries,
            onToggle: (_) {},
            onDelete: (_) {},
            onReorder: (_) {},
            onEdit: (_, __) {},
          ),
          floating: Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: EditorToolbarDock(
              child: ChecklistAddBar(onAdd: (_) {}),
            ),
          ),
        ),
      );
    });

    testWidgets('checklist all done shows the stickers', (tester) async {
      await golden(
        tester,
        'checklist_all_done',
        () => CustomScrollView(
          slivers: [
            ChecklistEditorSliver(
              items: [
                for (final e in groceries)
                  ChecklistEntry(id: e.id, text: e.text, done: true),
              ],
              onToggle: (_) {},
              onDelete: (_) {},
              onReorder: (_) {},
              onEdit: (_, __) {},
            ),
          ],
        ),
        size: const Size(390, 520),
        fullBleed: false,
      );
    });
  });

  group('behaviour', () {
    testWidgets('B is active inside bold text and toggles it off',
        (tester) async {
      final controller = boldController();
      await tester
          .pumpWidget(sketchApp(MarkdownToolbar(controller: controller)));
      final bold = find.bySemanticsLabel('Bold');
      expect(bold, findsOneWidget);
      expect(tester.getSemantics(bold), isSemantics(isSelected: true));

      // Select "bold" and toggle it off.
      controller
          .updateSelection(const TextSelection(baseOffset: 5, extentOffset: 9));
      await tester.pump();
      await tester.tap(bold);
      await tester.pump();
      expect(
        controller.document
            .collectStyle(5, 4)
            .containsSame(ParchmentAttribute.bold),
        isFalse,
      );
      // Let the controller's history throttle settle.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('highlight puts the marker colours on the selection',
        (tester) async {
      final controller = boldController()
        ..updateSelection(const TextSelection(baseOffset: 0, extentOffset: 4));
      await tester
          .pumpWidget(sketchApp(MarkdownToolbar(controller: controller)));

      // The highlight tool sits past the first screenful; scroll to it.
      final highlight = find.bySemanticsLabel('Highlight');
      await tester.ensureVisible(highlight);
      await tester.tap(highlight);
      await tester.pump();

      final style = controller.document.collectStyle(0, 4);
      expect(style.get(ParchmentAttribute.backgroundColor)?.value,
          MarkdownToolbar.highlightBackground);
      expect(style.get(ParchmentAttribute.foregroundColor)?.value,
          MarkdownToolbar.highlightForeground);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('add bar adds on Enter, clears and keeps focus',
        (tester) async {
      final added = <String>[];
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
          sketchApp(ChecklistAddBar(onAdd: added.add, focusNode: focus)));

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '  Buy milk ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(added, ['Buy milk']);
      expect(find.text('Buy milk'), findsNothing);
      expect(focus.hasFocus, isTrue);

      // Blank input adds nothing.
      await tester.tap(find.bySemanticsLabel('Add task'));
      expect(added, ['Buy milk']);
    });

    testWidgets('open tasks come before done ones; toggle and swipe report',
        (tester) async {
      final toggled = <int>[];
      final deleted = <int>[];
      await tester.pumpWidget(sketchApp(CustomScrollView(
        slivers: [
          ChecklistEditorSliver(
            items: const [
              ChecklistEntry(id: 3, text: 'Bread', done: true),
              ChecklistEntry(id: 1, text: 'Buy Milk', done: false),
            ],
            onToggle: (e) => toggled.add(e.id),
            onDelete: (e) => deleted.add(e.id),
            onReorder: (_) {},
            onEdit: (_, __) {},
          ),
        ],
      )));
      await tester.pumpAndSettle();

      final milk = tester.getTopLeft(find.text('Buy Milk'));
      final bread = tester.getTopLeft(find.text('Bread'));
      expect(milk.dy, lessThan(bread.dy));
      expect(find.text('1 of 2 done'), findsOneWidget);

      await tester.tap(find.byType(SketchCheckbox).first);
      expect(toggled, [1]);

      await tester.drag(find.text('Buy Milk'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(deleted, [1]);
    });

    testWidgets('folder chip names the first folder and counts the rest',
        (tester) async {
      await tester.pumpWidget(sketchApp(EditorFolderChip(
        folders: [
          NoteFolderDto(id: 1, title: 'Random'),
          NoteFolderDto(id: 2, title: 'Work'),
        ],
        colors: const {1: SketchPastels.yellow, 2: SketchPastels.mint},
        onTap: () {},
      )));
      expect(find.text('Random +1'), findsOneWidget);
      expect(find.bySemanticsLabel('Folders: Random, Work. Change folders'),
          findsOneWidget);
      expect(tester.getSize(find.byType(EditorFolderChip)).height,
          greaterThanOrEqualTo(44));
    });

    testWidgets('voice button turns into a timer while recording',
        (tester) async {
      await tester.pumpWidget(sketchApp(VoiceFab(
        recording: true,
        elapsed: const Duration(seconds: 42),
        semanticLabel: 'Tap to stop recording',
        onPressed: () {},
      )));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('0:42'), findsOneWidget);
      expect(find.bySemanticsLabel('Tap to stop recording'), findsOneWidget);
    });
  });
}
