import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../constants/premium_limits.dart';
import '../design_system/design_system.dart';
import '../models/folder_summary.dart';
import '../models/note_with_details.dart';
import '../screens/archive_screen.dart';
import '../screens/folder_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/subscription_screen.dart';
import '../screens/trash_screen.dart';
import '../service_locators/init_service_locators.dart';
import '../services/analytics/analytics_facade.dart';
import '../services/drift_note_folder_service.dart';
import '../services/drift_note_service.dart';
import '../services/premium_service.dart';
import '../services/theme_controller.dart';
import '../services/user_profile.dart';
import '../util/note_query.dart';
import 'app_shell_scope.dart';
import 'new_note.dart';

/// Opens a folder's note list.
void openFolder(BuildContext context, int folderId, String title) {
  context.push(
      '${FolderScreen.kRouteName}/$folderId/${Uri.encodeComponent(title)}');
}

/// The Sketchbook navigation drawer: profile, plan card, destinations with
/// counts, the folder list, and a Settings + Light/Dark footer.
///
/// Modal on phones; pinned open as a sidebar on tablets ([permanent]), where
/// it also carries the New note button the phone dock provides.
class KeepDrawer extends StatelessWidget {
  /// Sidebar width when pinned open on tablets.
  static const double permanentWidth = 300;

  final bool permanent;

  const KeepDrawer({super.key, this.permanent = false});

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final radius = const Radius.circular(SketchRadius.drawer);

    final content = DoodleBackground(
      top: DoodleBackground.drawerTop,
      child: SafeArea(
        child: _DrawerContent(permanent: permanent),
      ),
    );

    if (permanent) {
      return Container(
        width: permanentWidth,
        decoration: BoxDecoration(
          color: s.surface,
          border: BorderDirectional(
            end: BorderSide(color: s.outline, width: SketchStroke.outline),
          ),
        ),
        child: content,
      );
    }

    return Drawer(
      width: 316,
      backgroundColor: s.surface,
      shape: RoundedRectangleBorder(
        borderRadius: rtl
            ? BorderRadius.horizontal(left: radius)
            : BorderRadius.horizontal(right: radius),
        side: BorderSide(color: s.outline, width: SketchStroke.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

class _DrawerContent extends StatelessWidget {
  const _DrawerContent({required this.permanent});

  final bool permanent;

  /// Runs [action] after closing the modal drawer (a pinned one stays).
  void _go(BuildContext context, VoidCallback action) {
    if (!permanent) Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final shell = AppShellScope.maybeOf(context);
    final branch = shell?.currentBranch ?? 0;
    String? typeParam;
    try {
      typeParam = GoRouterState.of(context).uri.queryParameters['type'];
    } catch (_) {
      // Outside a go_router route (tests): no type filter is active.
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 16),
            children: [
              const _Profile(),
              const SizedBox(height: 14),
              _PlanCard(
                onUpgrade: () => _go(
                    context, () => context.push(SubscriptionScreen.kRouteName)),
              ),
              if (permanent) ...[
                const SizedBox(height: 14),
                PillButton(
                  label: l10n.dockNewNote,
                  icon: Icons.edit_rounded,
                  height: 50,
                  onPressed: () => NewNote.open(context),
                ),
              ],
              const SizedBox(height: 16),
              StreamBuilder<List<NoteWithDetails>>(
                stream: DriftNoteService.watchNotesWithDetailsV2(),
                builder: (context, snap) {
                  final notes = snap.data ?? const <NoteWithDetails>[];
                  int count(String type) => notes
                      .where((n) => NoteQuery.typeKey(n.note.noteType) == type)
                      .length;
                  return Column(
                    children: [
                      _MenuRow(
                        icon: Icons.sticky_note_2_outlined,
                        label: l10n.drawerAllNotes,
                        count: snap.hasData ? notes.length : null,
                        active:
                            (branch == 0 || branch == 1) && typeParam == null,
                        onTap: () => _go(context, () => shell?.goBranch(0)),
                      ),
                      _MenuRow(
                        icon: Icons.check_box_outlined,
                        label: l10n.todosTitle,
                        count: snap.hasData ? count('todo') : null,
                        active: branch == 2,
                        onTap: () => _go(context, () => shell?.goBranch(2)),
                      ),
                      _MenuRow(
                        icon: Icons.mic_none_rounded,
                        label: l10n.drawerVoiceNotes,
                        count: snap.hasData ? count('voice') : null,
                        active: branch == 1 && typeParam == 'voice',
                        onTap: () => _go(
                            context,
                            () => context
                                .go('${NotesScreen.kRouteName}?type=voice')),
                      ),
                      _MenuRow(
                        icon: Icons.alarm_rounded,
                        label: l10n.drawerReminders,
                        count: snap.hasData ? count('reminder') : null,
                        active: branch == 1 && typeParam == 'reminder',
                        onTap: () => _go(
                            context,
                            () => context
                                .go('${NotesScreen.kRouteName}?type=reminder')),
                      ),
                    ],
                  );
                },
              ),
              _MenuRow(
                icon: Icons.inventory_2_outlined,
                label: l10n.navArchive,
                onTap: () =>
                    _go(context, () => context.push(ArchiveScreen.kRouteName)),
              ),
              _MenuRow(
                icon: Icons.delete_outline_rounded,
                label: l10n.navTrash,
                onTap: () =>
                    _go(context, () => context.push(TrashScreen.kRouteName)),
              ),
              const _FolderList(),
            ],
          ),
        ),
        _Footer(
          onSettings: () =>
              _go(context, () => context.push(SettingsScreen.kRouteName)),
        ),
      ],
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final t = context.type;
    final profile = UserProfile.current();
    final subtitle = switch (profile.provider) {
      SignInProvider.google => l10n.signedInWithGoogle,
      SignInProvider.apple => l10n.signedInWithApple,
      SignInProvider.email => profile.email ?? '',
      SignInProvider.none => l10n.notSignedIn,
    };
    return Row(
      children: [
        SketchAvatar(name: profile.displayName, size: 50),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName ?? l10n.setAccountFallbackName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.cardTitleLarge,
              ),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final t = context.type;
    final premium = PremiumService();

    return ListenableBuilder(
      listenable: premium,
      builder: (context, _) {
        final isPro = premium.isPremium;
        final used = premium.getSyncedNotesCount();
        const limit = PremiumLimits.maxSyncedNotesForFree;
        return SketchCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          onTap: isPro ? null : onUpgrade,
          semanticLabel: isPro
              ? l10n.drawerProPlan
              : '${l10n.drawerFreePlan}, ${l10n.drawerSyncedNotes(used, limit)}',
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isPro ? l10n.drawerProPlan : l10n.drawerFreePlan,
                        style: t.body.copyWith(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                    SketchTag(
                      label: isPro ? l10n.drawerProBadge : l10n.usageUpgrade,
                      pastel:
                          isPro ? SketchPastels.lavender : SketchPastels.yellow,
                      textColor: SketchPastels.onPastel,
                    ),
                  ],
                ),
                if (!isPro) ...[
                  const SizedBox(height: 10),
                  UsageBar(
                    fraction: used / limit,
                    height: 8,
                    outlined: true,
                    fill: SketchPastels.mint,
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.drawerSyncedNotes(used, limit), style: t.caption),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(l10n.drawerProBody, style: t.caption),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final fg = active ? s.onInverse : s.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SketchPressable(
        onTap: onTap,
        selected: active,
        semanticLabel: count == null ? label : '$label, $count',
        child: AnimatedContainer(
          duration: SketchMotion.of(context, SketchMotion.base),
          height: 46,
          padding: const EdgeInsetsDirectional.only(start: 14, end: 16),
          decoration: BoxDecoration(
            color: active ? s.inverse : Colors.transparent,
            borderRadius: BorderRadius.circular(23),
          ),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Icon(icon, size: 19, color: fg),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.body.copyWith(color: fg)),
                ),
                if (count != null && count! > 0)
                  Text('$count',
                      style: t.bodySmall
                          .copyWith(color: active ? s.onInverse : s.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderList extends StatelessWidget {
  const _FolderList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final t = context.type;
    return StreamBuilder<List<FolderSummary>>(
      stream: DriftNoteFolderService.watchFolderSummaries(),
      builder: (context, snap) {
        final folders = snap.data ?? const <FolderSummary>[];
        if (folders.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SketchOverline(
              l10n.drawerFoldersOverline,
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
            ),
            for (final f in folders)
              SketchPressable(
                onTap: () {
                  final permanent =
                      AppShellScope.maybeOf(context)?.hasPermanentDrawer ??
                          false;
                  if (!permanent) Navigator.of(context).pop();
                  openFolder(context, f.id, f.title);
                },
                semanticLabel: '${f.title}, ${f.noteCount}',
                child: SizedBox(
                  height: 38,
                  child: ExcludeSemantics(
                    child: Padding(
                      padding:
                          const EdgeInsetsDirectional.only(start: 16, end: 16),
                      child: Row(
                        children: [
                          PastelSquare(color: f.color, size: 15),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(f.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodyRegular.copyWith(fontSize: 14)),
                          ),
                          if (f.noteCount > 0)
                            Text('${f.noteCount}', style: t.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final l10n = AppL10n.of(context);
    final theme = context.watch<ThemeController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: s.hairline, width: SketchStroke.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: SketchPressable(
                onTap: onSettings,
                semanticLabel: l10n.navSettings,
                child: SizedBox(
                  height: SketchSpace.minTap,
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        Icon(Icons.settings_outlined, size: 20, color: s.ink),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(l10n.navSettings,
                              overflow: TextOverflow.ellipsis,
                              style: context.type.body),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SketchSegmentedControl<Brightness>(
              semanticLabel: l10n.setTheme,
              segments: [
                SketchSegment(value: Brightness.light, label: l10n.themeLight),
                SketchSegment(value: Brightness.dark, label: l10n.themeDark),
              ],
              selected: isDark ? Brightness.dark : Brightness.light,
              onChanged: (b) {
                final mode =
                    b == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
                theme.setMode(mode);
                getIt<AnalyticsFacade>().trackThemeChanged(
                    theme: ThemeController.modeAnalyticsLabel(mode));
              },
            ),
          ],
        ),
      ),
    );
  }
}
