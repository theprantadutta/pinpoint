import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/design_system/design_system.dart';

import 'support/sketch_harness.dart';

/// Widget + golden coverage for the Sketchbook core components, in light and
/// dark. Regenerate goldens with `flutter test --update-goldens
/// test/sketch_components_test.dart` after an intentional visual change.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadSketchFonts);

  Future<void> golden(
    WidgetTester tester,
    String name,
    Widget child, {
    Size size = const Size(390, 520),
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    for (final b in Brightness.values) {
      await tester.pumpWidget(sketchApp(child, brightness: b));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/${name}_${b.name}.png'),
      );
    }
  }

  testWidgets('cards: outlined, pastel and dashed', (tester) async {
    await golden(
      tester,
      'card',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SketchCard(child: Text('Outlined card')),
          const SizedBox(height: 12),
          const SketchCard(
              pastel: SketchPastels.lavender, child: Text('Pastel card')),
          const SizedBox(height: 12),
          SketchCard(
              dashed: true,
              color: Colors.transparent,
              onTap: () {},
              child: const Center(child: Text('Dashed add'))),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(
                child: NoteCard(
                  title: 'Important Address',
                  excerpt: '221B Baker Street, London',
                  isPinned: true,
                  backgroundColor: SketchPastels.lavender,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: NoteCard(
                  title: 'Todos',
                  noteType: 'todo',
                  checklist: [
                    NoteChecklistItem(label: 'Buy Milk'),
                    NoteChecklistItem(label: 'Bread', isDone: true),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      size: const Size(390, 600),
    );
  });

  testWidgets('chips: unselected, selected and pastel-selected',
      (tester) async {
    await golden(
      tester,
      'chip',
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SketchChip(label: 'Random (5)', selected: true, onTap: () {}),
          SketchChip(label: 'HomeWork (3)', onTap: () {}),
          SketchChip(
              label: 'Text',
              selected: true,
              pastel: SketchPastels.yellow,
              onTap: () {}),
          SketchChip(
              label: 'Checklist',
              selected: true,
              pastel: SketchPastels.mint,
              onTap: () {}),
          const SketchTag(label: 'Pinned'),
          const SketchTag(
              label: 'Today, 6:00 PM',
              pastel: SketchPastels.lavender,
              icon: Icons.alarm_rounded,
              dense: false),
        ],
      ),
      size: const Size(390, 260),
    );
  });

  testWidgets('dock', (tester) async {
    await golden(
      tester,
      'dock',
      Center(
        child: SketchDock(
          items: const [
            SketchDockItem(icon: Icons.home_outlined, label: 'Home'),
            SketchDockItem(icon: Icons.folder_outlined, label: 'Notes'),
            SketchDockItem(icon: Icons.check_box_outlined, label: 'Todos'),
            SketchDockItem(icon: Icons.person_outline, label: 'Settings'),
          ],
          currentIndex: 0,
          onSelect: (_) {},
          onCreate: () {},
          createLabel: 'New note',
        ),
      ),
      size: const Size(390, 200),
    );
  });

  testWidgets('checklist rows and progress card', (tester) async {
    await golden(
      tester,
      'checklist_row',
      Column(
        children: [
          const ProgressCard(
            done: 2,
            total: 4,
            label: 'Progress',
            summary: '2 of 4 done',
          ),
          const SizedBox(height: 12),
          ChecklistRow(label: 'Buy Milk', checked: false, onChanged: (_) {}),
          const SizedBox(height: 10),
          ChecklistRow(label: 'Bread', checked: true, onChanged: (_) {}),
        ],
      ),
      size: const Size(390, 420),
    );
  });

  testWidgets('folder tiles', (tester) async {
    await golden(
      tester,
      'folder_tile',
      Column(
        children: [
          const FolderPreviewCard(
            title: 'Random',
            countLabel: '5 notes',
            backPastel: SketchPastels.yellow,
            frontPastel: SketchPastels.lavender,
            entries: [
              FolderPreviewEntry(title: 'Random Note', color: SketchPastels.mint),
              FolderPreviewEntry(title: 'Spider-Man', color: SketchPastels.sky),
              FolderPreviewEntry(
                  title: 'Important Address', color: SketchPastels.lavender),
              FolderPreviewEntry(title: 'Todos', color: SketchPastels.yellow),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: FolderTile(
                  title: 'Workout',
                  subtitle: '2 notes · 1 voice',
                  pastel: SketchPastels.mint,
                  noteColors: [SketchPastels.lavender, SketchPastels.yellow],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: NewFolderTile(label: 'New folder', onTap: () {}),
              ),
            ],
          ),
        ],
      ),
      size: const Size(390, 440),
    );
  });

  testWidgets('controls: toggle and segmented control', (tester) async {
    await golden(
      tester,
      'controls',
      SketchGroup(
        margin: EdgeInsets.zero,
        children: [
          SketchRow(
              label: 'Pinned only',
              trailing: SketchToggle(value: true, onChanged: (_) {})),
          SketchRow(
              label: 'Include archived',
              trailing: SketchToggle(value: false, onChanged: (_) {})),
          SketchRow(
            label: 'Theme',
            trailing: SketchSegmentedControl<int>(
              segments: const [
                SketchSegment(value: 0, label: 'Light'),
                SketchSegment(value: 1, label: 'Dark'),
                SketchSegment(value: 2, label: 'Auto'),
              ],
              selected: 0,
              onChanged: (_) {},
            ),
          ),
        ],
      ),
      size: const Size(390, 260),
    );
  });

  group('behaviour', () {
    testWidgets('toggle reports its state and flips on tap', (tester) async {
      var value = false;
      await tester.pumpWidget(sketchApp(StatefulBuilder(
        builder: (context, setState) => SketchToggle(
          value: value,
          semanticLabel: 'Pinned only',
          onChanged: (v) => setState(() => value = v),
        ),
      )));
      await tester.tap(find.byType(SketchToggle));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect(
        tester.getSemantics(find.byType(SketchToggle)),
        matchesSemantics(
          label: 'Pinned only',
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          isButton: true,
        ),
      );
    });

    testWidgets('circle icon buttons are at least 44px and labelled',
        (tester) async {
      await tester.pumpWidget(sketchApp(Center(
        child: CircleIconButton(
          icon: Icons.search_rounded,
          semanticLabel: 'Search',
          onPressed: () {},
        ),
      )));
      final size = tester.getSize(find.byType(CircleIconButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      expect(find.bySemanticsLabel('Search'), findsOneWidget);
    });

    testWidgets('pastel chips prefix a check and keep ink text in dark',
        (tester) async {
      await tester.pumpWidget(sketchApp(
        SketchChip(
          label: 'Text',
          selected: true,
          pastel: SketchPastels.yellow,
          onTap: () {},
        ),
        brightness: Brightness.dark,
      ));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      final text = tester.widget<Text>(find.text('Text'));
      final style = DefaultTextStyle.of(tester.element(find.text('Text')))
          .style
          .merge(text.style);
      expect(style.color, SketchPastels.onPastel);
    });

    testWidgets('doodles stay off when the OS removes animations',
        (tester) async {
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: sketchApp(const DoodleBackground(child: SizedBox())),
      ));
      expect(find.byType(CustomPaint).evaluate().where((e) {
        final w = e.widget as CustomPaint;
        return w.painter is DoodlePainter;
      }), isEmpty);
    });

    test('display token picks a short leading number', () {
      expect(NoteCard.displayToken('221B Baker Street, London'),
          (token: '221B', rest: 'Baker Street, London'));
      expect(NoteCard.displayToken('42\nThe answer'),
          (token: '42', rest: 'The answer'));
      expect(NoteCard.displayToken('Groceries for the week'), isNull);
    });

    test('card previews render markdown bullets as dots', () {
      expect(NoteCard.previewText('- one\n* two\n1. three\n# Heading'),
          '• one\n• two\n• three\nHeading');
    });
  });
}
