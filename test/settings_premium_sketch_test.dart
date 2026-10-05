import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/components/paywall/paywall_widgets.dart';
import 'package:pinpoint/components/settings/settings_account_card.dart';
import 'package:pinpoint/components/settings/settings_appearance_group.dart';
import 'package:pinpoint/components/settings/settings_format.dart';
import 'package:pinpoint/components/settings/settings_usage_section.dart';
import 'package:pinpoint/components/settings/settings_widgets.dart';
import 'package:pinpoint/constants/premium_limits.dart';
import 'package:pinpoint/design_system/design_system.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/services/theme_controller.dart';
import 'package:pinpoint/widgets/premium_gate_dialog.dart';

import 'support/analytics_recorder.dart';
import 'support/sketch_harness.dart';

/// Settings and Premium in the Sketchbook system: goldens for the account
/// card, a settings group (segmented control, accent dots, toggle) and the
/// paywall, plus behaviour of the limit sheet and the pure helpers.
///
/// Regenerate with
/// `flutter test --update-goldens test/settings_premium_sketch_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadSketchFonts);

  Future<void> golden(
    WidgetTester tester,
    String name,
    Widget child, {
    Size size = const Size(390, 520),
    bool settle = true,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    for (final b in Brightness.values) {
      await tester.pumpWidget(sketchApp(child, brightness: b));
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        // A spinner never settles.
        await tester.pump(const Duration(milliseconds: 400));
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/${name}_${b.name}.png'),
      );
    }
  }

  bool freeAccent(SketchAccent a) =>
      PremiumLimits.freeThemeColors.contains(a.premiumName);

  testWidgets('account card: synced, syncing and failed', (tester) async {
    await golden(
      tester,
      'settings_account_card',
      Column(
        children: [
          SettingsAccountCard(
            name: 'Pranta Dutta',
            subtitle: 'Signed in with Google',
            state: AccountSyncState.synced,
            statusText: 'All notes synced · 2 min ago',
            onSyncNow: () {},
            onTap: () {},
          ),
          const SizedBox(height: 14),
          SettingsAccountCard(
            name: 'Pranta Dutta',
            subtitle: 'Signed in with Google',
            state: AccountSyncState.syncing,
            statusText: 'Syncing 3 changes…',
            onSyncNow: () {},
          ),
          const SizedBox(height: 14),
          SettingsAccountCard(
            name: 'Pranta Dutta',
            subtitle: 'Signed in with Apple',
            state: AccountSyncState.failed,
            statusText: 'Sync failed · Retry',
            onSyncNow: () {},
            onRetry: () {},
          ),
        ],
      ),
      size: const Size(390, 560),
      settle: false,
    );
  });

  testWidgets('settings groups: segmented theme, accent dots, toggle, usage',
      (tester) async {
    await golden(
      tester,
      'settings_groups',
      Builder(builder: (context) {
        final l10n = AppL10n.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SketchOverline(l10n.setSectionAppearance,
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8)),
            SketchGroup(
              margin: EdgeInsets.zero,
              children: [
                SketchRow(
                  label: l10n.setTheme,
                  trailing: ThemeModeSwitch(
                      mode: ThemeMode.light, onChanged: (_) {}),
                ),
                SketchRow(
                  label: l10n.stAccent,
                  trailing: AccentDots(
                    selected: SketchAccent.mint,
                    isAvailable: freeAccent,
                    onSelect: (_) {},
                  ),
                ),
                SketchRow(
                    label: l10n.stFont,
                    value: 'Plus Jakarta Sans',
                    onTap: () {}),
              ],
            ),
            SketchOverline(l10n.stSectionPrivacy,
                padding: const EdgeInsets.fromLTRB(4, 20, 4, 8)),
            SketchGroup(
              margin: EdgeInsets.zero,
              children: [
                SketchRow(
                  label: l10n.stBiometricLock,
                  trailing: SketchToggle(value: true, onChanged: (_) {}),
                ),
                SketchRow(
                  label: l10n.stZeroKnowledge,
                  subtitle: l10n.stZeroKnowledgeSubtitle,
                  trailing: SettingsValue(l10n.stOff),
                  chevron: true,
                  onTap: () {},
                ),
                SketchRow(
                  label: l10n.setEncryption,
                  trailing: SketchTag(
                    label: l10n.stEncryptionPill,
                    pastel: SketchPastels.mint,
                    dense: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: UsageCountCard(
                        label: l10n.stSyncedNotes, used: 38, limit: 50),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: UsageCountCard(
                        label: l10n.stOcrScans, used: 4, limit: 20),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
      size: const Size(390, 760),
    );
  });

  testWidgets('paywall: collage, headline, limits and plan cards',
      (tester) async {
    await golden(
      tester,
      'paywall',
      Builder(builder: (context) {
        final l10n = AppL10n.of(context);
        final t = context.type;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PaywallStickerCollage(animate: false),
              HighlightedText(l10n.pwHeadline, style: t.heroTitle),
              const SizedBox(height: 10),
              Text(l10n.pwSubtitle,
                  style: t.bodyRegular
                      .copyWith(fontSize: 14, color: context.sketch.muted)),
              const SizedBox(height: 16),
              PaywallLimitsTable(rows: paywallLimitRows(l10n)),
              const SizedBox(height: 24),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: PaywallPlanCard(
                        title: l10n.subPlanMonthly,
                        price: r'$2.99',
                        selected: false,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PaywallPlanCard(
                        title: l10n.subPlanYearly,
                        price: r'$19.99',
                        selected: true,
                        badge: l10n.pwSave(44),
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              PaywallPlanCard(
                title: l10n.subPlanLifetime,
                price: r'$29.99',
                caption: l10n.subBadgePayOnce,
                selected: false,
                onTap: () {},
              ),
              const SizedBox(height: 14),
              PillButton(label: l10n.pwContinue, onPressed: () {}),
            ],
          ),
        );
      }),
      size: const Size(390, 1100),
    );
  });

  testWidgets('the limits table quotes PremiumLimits, accents included',
      (tester) async {
    await tester.pumpWidget(sketchApp(Builder(
      builder: (context) =>
          PaywallLimitsTable(rows: paywallLimitRows(AppL10n.of(context))),
    )));
    await tester.pumpAndSettle();

    expect(find.text('${PremiumLimits.maxSyncedNotesForFree}'), findsOneWidget);
    expect(find.text('${PremiumLimits.maxFoldersForFree}/mo'), findsNothing);
    expect(find.text('${PremiumLimits.maxOcrScansPerMonthForFree}/mo'),
        findsOneWidget);
    expect(find.text('${PremiumLimits.maxThemeColorsForFree}'), findsOneWidget);
    expect(find.text('All ${PremiumLimits.totalThemeColors}'), findsOneWidget);
  });

  group('premium limit sheet', () {
    late RecordingAnalyticsFacade analytics;

    setUp(() {
      analytics = RecordingAnalyticsFacade();
      if (getIt.isRegistered<AnalyticsFacade>()) {
        getIt.unregister<AnalyticsFacade>();
      }
      getIt.registerSingleton<AnalyticsFacade>(analytics);
    });

    tearDown(() {
      if (getIt.isRegistered<AnalyticsFacade>()) {
        getIt.unregister<AnalyticsFacade>();
      }
    });

    testWidgets('folder limit: sticker, count title, See Pro and Not now',
        (tester) async {
      await tester.pumpWidget(sketchApp(Builder(
        builder: (context) => TextButton(
          onPressed: () => PremiumGateDialog.showFolderLimit(context),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(SketchSheet), findsOneWidget);
      expect(find.byType(StickerTile), findsOneWidget);
      expect(find.text("You've used 5 of 5 folders"), findsOneWidget);
      expect(find.text('See Pro'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      expect(analytics.one('premium_gate_shown').params['feature'], 'folders');

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.byType(SketchSheet), findsNothing);
    });

    testWidgets('every entry point still opens a sheet', (tester) async {
      final openers = <Future<void> Function(BuildContext)>[
        (c) => PremiumGateDialog.showSyncLimit(c, 0),
        (c) => PremiumGateDialog.showOcrLimit(c, 0),
        PremiumGateDialog.showExportLimit,
        PremiumGateDialog.showVoiceRecordingLimit,
        PremiumGateDialog.showFolderLimit,
        PremiumGateDialog.showThemeLimit,
        (c) => PremiumGateDialog.showFileAttachmentLimit(c, 3, 3),
      ];
      late BuildContext ctx;
      await tester.pumpWidget(sketchApp(Builder(builder: (context) {
        ctx = context;
        return const SizedBox.shrink();
      })));
      for (final open in openers) {
        open(ctx);
        await tester.pumpAndSettle();
        expect(find.byType(PremiumGateDialog), findsOneWidget);
        await tester.tap(find.text('Not now'));
        await tester.pumpAndSettle();
      }
      expect(analytics.all('premium_gate_shown'), hasLength(openers.length));
    });
  });

  group('helpers', () {
    testWidgets('relativeAgo uses plurals, then a localized day',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(sketchApp(Builder(builder: (context) {
        ctx = context;
        return const SizedBox.shrink();
      })));
      final now = DateTime(2026, 10, 5, 12);
      expect(relativeAgo(ctx, now.subtract(const Duration(seconds: 20)),
          now: now), 'just now');
      expect(relativeAgo(ctx, now.subtract(const Duration(minutes: 1)),
          now: now), '1 min ago');
      expect(relativeAgo(ctx, now.subtract(const Duration(minutes: 2)),
          now: now), '2 min ago');
      expect(relativeAgo(ctx, now.subtract(const Duration(hours: 3)),
          now: now), '3 h ago');
      expect(relativeAgo(ctx, now.subtract(const Duration(days: 1)), now: now),
          startsWith('Yesterday'));
    });

    test('a stored "Source Sans Pro" no longer crashes the theme', () {
      expect(ThemeController.normalizeFontFamily('Source Sans Pro'),
          'Source Sans 3');
      expect(ThemeController.normalizeFontFamily('Inter'), 'Inter');
      expect(ThemeController.normalizeFontFamily('Comic Sans'),
          PinpointTypography.primaryFontFamily);
      for (final f in PinpointTypography.selectableFonts) {
        expect(() => PinpointTypography.fontPreview(f), returnsNormally,
            reason: '$f must be a family google_fonts knows');
      }
    });

    testWidgets('accent dots announce Pro-only colours', (tester) async {
      SketchAccent? picked;
      await tester.pumpWidget(sketchApp(AccentDots(
        selected: SketchAccent.mint,
        isAvailable: freeAccent,
        onSelect: (a) => picked = a,
      )));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Purple Dream accent, Pro only'),
          findsOneWidget);
      expect(find.bySemanticsLabel('Neon Mint accent'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Purple Dream accent, Pro only'));
      expect(picked, SketchAccent.iris,
          reason: 'The dots report the tap; selectAccent applies the gate.');
    });
  });
}
