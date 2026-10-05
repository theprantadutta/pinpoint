import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/components/shared/app_update_prompt.dart';
import 'package:pinpoint/services/update/app_release_policy.dart';
import 'package:pinpoint/services/update/app_release_service.dart';
import 'package:pinpoint/services/update/update_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/sketch_harness.dart';

/// The update rules, ported from Snake Classic.
///
/// The blocking path is the one pinned hardest: it takes the user's notes away
/// until they act, so every route into it must be deliberate and every
/// ambiguity must route away from it.
void main() {
  group('AppVersion', () {
    test('orders by segment value, not lexicographically', () {
      expect(AppVersion.tryParse('4.0.10')!.compareTo(AppVersion.tryParse('4.0.9')!),
          greaterThan(0));
    });

    test('treats a missing segment as zero', () {
      expect(AppVersion.tryParse('4.1')!.compareTo(AppVersion.tryParse('4.1.0')!), 0);
    });

    test('rejects anything that is not dotted numerics', () {
      for (final bad in [
        null, '', '   ', 'v4.0.0', '4.0.0+36', '4.0.0-beta', '4..0', '4.0.',
        '4.0.0.1.2', '+4.0', '-4.0', '1234567',
      ]) {
        expect(AppVersion.tryParse(bad), isNull, reason: 'should reject "$bad"');
      }
    });

    test('accepts the shapes an operator types', () {
      for (final good in ['4', '4.1', '4.1.0', '4.1.0.36', ' 4.1.0 ']) {
        expect(AppVersion.tryParse(good), isNotNull, reason: 'should accept "$good"');
      }
    });
  });

  group('iOS: AppReleasePolicy.decide', () {
    UpdatePrompt decide({
      bool enabled = true,
      String? current = '4.0.0',
      String? latest = '4.2.0',
      String? minimum = '3.9.0',
      Duration? sinceDeclined,
    }) =>
        AppReleasePolicy.decide(
          enabled: enabled,
          currentVersion: current,
          latestVersion: latest,
          minimumSupportedVersion: minimum,
          sinceDeclined: sinceDeclined,
        );

    test('below the floor blocks, and a fresh decline cannot snooze it', () {
      expect(decide(current: '3.4.0'), UpdatePrompt.required);
      expect(decide(current: '3.4.0', sinceDeclined: const Duration(minutes: 1)),
          UpdatePrompt.required);
    });

    test('behind the latest but above the floor is dismissible', () {
      expect(decide(), UpdatePrompt.optional);
      expect(decide(current: '3.9.0', minimum: '3.9.0'), UpdatePrompt.optional);
    });

    test('on or ahead of the latest says nothing', () {
      expect(decide(current: '4.2.0'), UpdatePrompt.none);
      expect(decide(current: '4.3.0'), UpdatePrompt.none);
    });

    test('a recent decline snoozes the nudge for a day', () {
      expect(decide(sinceDeclined: const Duration(hours: 1)), UpdatePrompt.none);
      expect(decide(sinceDeclined: const Duration(hours: 25)), UpdatePrompt.optional);
    });

    test('disabled says nothing, whatever the versions claim', () {
      expect(decide(enabled: false, current: '1.0.0'), UpdatePrompt.none);
    });

    test('never blocks on an unknown', () {
      expect(decide(current: 'garbage'), UpdatePrompt.none);
      expect(decide(current: null), UpdatePrompt.none);
      expect(decide(minimum: 'nonsense'), UpdatePrompt.optional);
      expect(decide(latest: 'nonsense'), UpdatePrompt.none);
      expect(decide(current: '3.0.0', latest: 'nonsense'), UpdatePrompt.required);
      expect(decide(latest: null, minimum: null), UpdatePrompt.none);
    });
  });

  group('Android: UpdatePolicy.decide', () {
    UpdateFlow decide({
      bool available = true,
      int priority = 0,
      bool immediate = true,
      bool flexible = true,
      Duration? sinceDeclined,
    }) =>
        UpdatePolicy.decide(
          updateAvailable: available,
          priority: priority,
          immediateAllowed: immediate,
          flexibleAllowed: flexible,
          sinceDeclined: sinceDeclined,
        );

    test('a routine release downloads in the background', () {
      expect(decide(), UpdateFlow.flexible);
    });

    test('only an urgent release gets the blocking flow, even when snoozed', () {
      expect(decide(priority: 3), UpdateFlow.flexible);
      expect(decide(priority: 4), UpdateFlow.immediate);
      expect(decide(priority: 5, sinceDeclined: const Duration(minutes: 1)),
          UpdateFlow.immediate);
    });

    test('a declined offer is left alone for a day', () {
      expect(decide(sinceDeclined: const Duration(hours: 2)), UpdateFlow.none);
      expect(decide(sinceDeclined: const Duration(hours: 25)), UpdateFlow.flexible);
    });

    test('nothing available, or only a wall for a routine release, does nothing', () {
      expect(decide(available: false), UpdateFlow.none);
      expect(decide(flexible: false), UpdateFlow.none);
    });
  });

  group('AppReleaseService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a failed fetch, e.g. offline, is silence rather than a blocked app', () async {
      final prompt = await AppReleaseService.forTesting().check(
        force: true,
        currentVersionOverride: '1.0.0',
        fetch: () async => throw Exception('offline'),
      );
      expect(prompt, UpdatePrompt.none);
    });

    test('reads the snake_case policy the server sends', () async {
      final service = AppReleaseService.forTesting();
      final prompt = await service.check(
        force: true,
        currentVersionOverride: '4.0.0',
        fetch: () async => {
          'platform': 'ios',
          'latest_version': '4.1.0',
          'minimum_supported_version': '4.0.0',
          'store_url': 'https://apps.apple.com/app/id6786222392',
          'enabled': true,
        },
      );
      expect(prompt, UpdatePrompt.optional);
      expect(service.latestVersion, '4.1.0');
      expect(service.storeUrl, startsWith('https://apps.apple.com'));
    });
  });

  group('update sheet', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> open(WidgetTester tester, UpdatePrompt prompt,
        {String? url = 'https://apps.apple.com/app/id6786222392'}) async {
      // The sheet reads its destination off the singleton, and refuses to
      // open at all without one.
      AppReleaseService().storeUrl = url;
      AppReleaseService().latestVersion = '4.1.0';
      await tester.pumpWidget(sketchApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppUpdatePrompt(context, prompt),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('optional names the version and offers Later', (tester) async {
      await open(tester, UpdatePrompt.optional);
      expect(find.text('A new version is ready'), findsOneWidget);
      expect(find.textContaining('4.1.0'), findsOneWidget);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('A new version is ready'), findsNothing);
    });

    testWidgets('optional closes on a scrim tap', (tester) async {
      await open(tester, UpdatePrompt.optional);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('A new version is ready'), findsNothing);
    });

    testWidgets('required has no Later and survives the scrim and back', (tester) async {
      await open(tester, UpdatePrompt.required);
      expect(find.text('Update Required'), findsOneWidget);
      expect(find.text('Later'), findsNothing);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Update Required'), findsOneWidget);

      // What Android's back button / iOS's back swipe delivers.
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.text('Update Required'), findsOneWidget);
    });

    testWidgets('nothing opens without a store URL, or for none', (tester) async {
      await open(tester, UpdatePrompt.required, url: null);
      expect(find.text('Update Required'), findsNothing);

      await open(tester, UpdatePrompt.none);
      expect(find.text('A new version is ready'), findsNothing);
    });
  });
}
