import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../components/shared/folder_actions.dart';
import '../constants/premium_limits.dart';
import '../design_system/design_system.dart';
import '../models/folder_summary.dart';
import '../navigation/keep_drawer.dart';
import '../service_locators/init_service_locators.dart';
import '../services/analytics/analytics_facade.dart';
import '../services/crash_breadcrumbs.dart';
import '../services/drift_note_folder_service.dart';
import '../services/logger_service.dart';
import '../services/premium_service.dart';
import '../widgets/pinpoint_popup_menu_button.dart';
import 'subscription_screen.dart';

/// My folders: a two-column grid of [FolderTile]s ending in a dashed
/// "New folder" tile, with a free-limit banner for free users near the cap.
///
/// Long-press a folder to reorder: tiles wiggle by 1° (not under reduced
/// motion), press-and-drag moves one, and the order is saved with
/// [DriftNoteFolderService.setFolderOrder].
class MyFoldersScreen extends StatefulWidget {
  static const String kRouteName = '/my-folders';

  const MyFoldersScreen({super.key});

  @override
  State<MyFoldersScreen> createState() => _MyFoldersScreenState();
}

class _MyFoldersScreenState extends State<MyFoldersScreen>
    with SingleTickerProviderStateMixin {
  late final Stream<List<FolderSummary>> _stream =
      DriftNoteFolderService.watchFolderSummaries();

  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  /// Folder ids in the order being edited; null outside reorder mode.
  List<int>? _order;

  bool get _reordering => _order != null;

  @override
  void initState() {
    super.initState();
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'MyFolders');
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  void _startReorder(List<FolderSummary> folders) {
    PinpointHaptics.medium();
    setState(() => _order = [for (final f in folders) f.id]);
    if (SketchMotion.enabled(context)) _wiggle.repeat(reverse: true);
  }

  void _endReorder() {
    _wiggle
      ..stop()
      ..value = 0;
    setState(() => _order = null);
  }

  /// Moves [id] to [index] in the edited order.
  void _move(int id, int index) {
    final order = _order;
    if (order == null) return;
    final from = order.indexOf(id);
    if (from < 0 || from == index) return;
    setState(() {
      order.removeAt(from);
      order.insert(index.clamp(0, order.length), id);
    });
  }

  Future<void> _persistOrder() async {
    final order = _order;
    if (order == null) return;
    PinpointHaptics.selection();
    await DriftNoteFolderService.setFolderOrder(List.of(order));
  }

  /// [folders] in the edited order (new folders from sync go last).
  List<FolderSummary> _arranged(List<FolderSummary> folders) {
    final order = _order;
    if (order == null) return folders;
    final byId = {for (final f in folders) f.id: f};
    return [
      for (final id in order)
        if (byId[id] != null) byId[id]!,
      for (final f in folders)
        if (!order.contains(f.id)) f,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;

    return StreamBuilder<List<FolderSummary>>(
      stream: _stream,
      builder: (context, snapshot) {
        final folders = snapshot.data;

        final Widget body;
        if (snapshot.hasError) {
          log.e('[my-folders] stream error', snapshot.error);
          body = EmptyState(
            icon: Icons.error_outline_rounded,
            title: l10n.foldersSomethingWrong,
            message: l10n.foldersLoadFailed,
          );
        } else if (folders == null) {
          body = const SizedBox.shrink();
        } else if (folders.isEmpty) {
          body = EmptyState(
            icon: Icons.folder_open_rounded,
            title: l10n.foldersEmptyTitle,
            message: l10n.foldersEmptyHint,
            actionLabel: l10n.foldersCreate,
            onAction: () => FolderActions.create(context),
          );
        } else {
          body = SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                SketchSpace.screenX, 20, SketchSpace.screenX, 24),
            child: FolderGrid(
              folders: _arranged(folders),
              reordering: _reordering,
              wiggle: _wiggle,
              onLongPress: () => _startReorder(folders),
              onMove: _move,
              onDropped: _persistOrder,
              onCreate: () => FolderActions.create(context),
            ),
          );
        }

        final Widget action = _reordering
            ? SketchTextAction(
                label: l10n.commonDone,
                style: context.type.body,
                onTap: _endReorder,
              )
            : CircleIconButton(
                icon: Icons.add_rounded,
                iconSize: 24,
                fill: s.inverse,
                semanticLabel: l10n.foldersCreate,
                onPressed: () {
                  PinpointHaptics.light();
                  FolderActions.create(context);
                },
              );

        return PopScope(
          canPop: !_reordering,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _reordering) _endReorder();
          },
          child: SketchScaffold(
            largeTitle: true,
            title: l10n.foldersMyFolders,
            subtitle: _reordering ? l10n.flReorderHint : l10n.flSubtitle,
            doodleTop: DoodleBackground.foldersTop,
            squiggle: true,
            onBack: () {
              PinpointHaptics.light();
              if (_reordering) {
                _endReorder();
              } else {
                context.pop();
              }
            },
            actions: [action],
            body: body,
            bottom: folders == null || _reordering
                ? null
                : FolderLimitBanner(folderCount: folders.length),
          ),
        );
      },
    );
  }
}

/// The free-plan banner: "{used} of 5 free folders used · Upgrade". Only for
/// free users at or one below the cap.
class FolderLimitBanner extends StatelessWidget {
  const FolderLimitBanner({
    super.key,
    required this.folderCount,
    this.premium,
  });

  final int folderCount;

  /// For tests; defaults to the app's [PremiumService].
  final PremiumService? premium;

  static const int _limit = PremiumLimits.maxFoldersForFree;

  static bool shouldShow({required bool isPremium, required int count}) =>
      !isPremium && count >= _limit - 1;

  @override
  Widget build(BuildContext context) {
    final service = premium ?? PremiumService();
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (!shouldShow(isPremium: service.isPremium, count: folderCount)) {
          return const SizedBox.shrink();
        }
        final l10n = AppL10n.of(context);
        return UpgradeBanner(
          title: l10n.flFreeLimitTitle(math.min(folderCount, _limit), _limit),
          message: l10n.flFreeLimitBody,
          actionLabel: l10n.usageUpgrade,
          onAction: () => context.push(SubscriptionScreen.kRouteName),
        );
      },
    );
  }
}

/// The folders grid: [FolderTile]s two (or, on wide layouts, three) per row,
/// gaps 16 × 14, ending in the dashed New folder tile.
class FolderGrid extends StatelessWidget {
  const FolderGrid({
    super.key,
    required this.folders,
    required this.onCreate,
    this.reordering = false,
    this.wiggle,
    this.onLongPress,
    this.onMove,
    this.onDropped,
  });

  final List<FolderSummary> folders;
  final VoidCallback onCreate;
  final bool reordering;
  final Animation<double>? wiggle;
  final VoidCallback? onLongPress;
  final void Function(int id, int index)? onMove;
  final VoidCallback? onDropped;

  static const double rowGap = 16;
  static const double columnGap = 14;
  static const double tileHeight = 150;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 560 ? 3 : 2;
        final w = (c.maxWidth - columnGap * (columns - 1)) / columns;

        final tiles = <Widget>[
          for (var i = 0; i < folders.length; i++)
            SizedBox(
              key: ValueKey(folders[i].id),
              width: w,
              child: _FolderGridTile(
                summary: folders[i],
                index: i,
                count: folders.length,
                width: w,
                reordering: reordering,
                wiggle: wiggle,
                onLongPress: onLongPress,
                onMove: onMove,
                onDropped: onDropped,
              ),
            ),
          if (!reordering)
            SizedBox(
              width: w,
              child: NewFolderTile(label: l10n.flNewFolder, onTap: onCreate),
            ),
        ];

        return Wrap(
          spacing: columnGap,
          runSpacing: rowGap,
          children: tiles,
        );
      },
    );
  }
}

class _FolderGridTile extends StatelessWidget {
  const _FolderGridTile({
    required this.summary,
    required this.index,
    required this.count,
    required this.width,
    required this.reordering,
    this.wiggle,
    this.onLongPress,
    this.onMove,
    this.onDropped,
  });

  final FolderSummary summary;
  final int index;
  final int count;
  final double width;
  final bool reordering;
  final Animation<double>? wiggle;
  final VoidCallback? onLongPress;
  final void Function(int id, int index)? onMove;
  final VoidCallback? onDropped;

  static String subtitle(AppL10n l10n, FolderSummary f) {
    final notes = l10n.folderNoteCount(f.noteCount);
    if (f.voiceCount == 0) return notes;
    return l10n.folderSummarySeparator(
        notes, l10n.folderVoiceCount(f.voiceCount));
  }

  Widget _tile(BuildContext context, {bool interactive = true}) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;
    final f = summary;
    return FolderTile(
      title: f.title,
      subtitle: subtitle(l10n, f),
      pastel: f.color,
      noteColors: [for (final n in f.recent) n.color],
      height: FolderGrid.tileHeight,
      onTap: !interactive || reordering
          ? null
          : () {
              PinpointHaptics.medium();
              openFolder(context, f.id, f.title);
            },
      onLongPress: !interactive || reordering ? null : onLongPress,
      menu: !interactive || reordering
          ? null
          : PinpointPopupMenuButton<String>(
              tooltip: l10n.flMenuLabel(f.title),
              icon: Icon(Icons.more_horiz_rounded, color: s.muted),
              onOpened: () => CrashBreadcrumbs.popupMenuOpened('folders.tile'),
              onCanceled: () =>
                  CrashBreadcrumbs.popupMenuClosed('folders.tile'),
              onSelected: (value) {
                CrashBreadcrumbs.popupMenuClosed('folders.tile',
                    selected: value);
                switch (value) {
                  case 'rename':
                    FolderActions.rename(context, f.id, f.title);
                  case 'colour':
                    FolderActions.changeColour(context, f.id, f.color);
                  case 'delete':
                    FolderActions.delete(context, f.id, f.title);
                }
              },
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!reordering) return _tile(context);

    final l10n = AppL10n.of(context);
    final wig = wiggle;
    // Alternate directions so neighbours rock against each other.
    final sign = index.isEven ? 1.0 : -1.0;
    Widget tile = _tile(context);
    if (wig != null && SketchMotion.enabled(context)) {
      tile = AnimatedBuilder(
        animation: wig,
        builder: (_, child) => Transform.rotate(
          angle: sign * (wig.value * 2 - 1) * math.pi / 180,
          child: child,
        ),
        child: tile,
      );
    }

    final draggable = LongPressDraggable<int>(
      data: summary.id,
      delay: const Duration(milliseconds: 150),
      hapticFeedbackOnStart: true,
      onDragEnd: (_) => onDropped?.call(),
      feedback: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: width,
          child: Transform.rotate(
            angle: -2 * math.pi / 180,
            child: _tile(context, interactive: false),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _tile(context)),
      child: tile,
    );

    return Semantics(
      customSemanticsActions: {
        if (index > 0)
          CustomSemanticsAction(label: l10n.flMoveEarlier): () {
            onMove?.call(summary.id, index - 1);
            onDropped?.call();
          },
        if (index < count - 1)
          CustomSemanticsAction(label: l10n.flMoveLater): () {
            onMove?.call(summary.id, index + 1);
            onDropped?.call();
          },
      },
      child: DragTarget<int>(
        onWillAcceptWithDetails: (d) {
          if (d.data != summary.id) onMove?.call(d.data, index);
          return true;
        },
        builder: (_, __, ___) => draggable,
      ),
    );
  }
}

/// "{n} notes · {k} voice" — the count line under a folder's name.
String folderSubtitle(AppL10n l10n, FolderSummary f) =>
    _FolderGridTile.subtitle(l10n, f);
