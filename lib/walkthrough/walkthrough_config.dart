import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'walkthrough_keys.dart';
import 'walkthrough_content.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

/// Configuration for walkthrough targets.
/// Defines the order, content, and appearance of each coach mark.
class WalkthroughConfig {
  WalkthroughConfig._();

  /// Mint color used in the app's primary accent
  static const Color _mintColor = Color(0xFF4ECCA3);

  // tutorial_coach_mark's `alignSkip` is typed as a plain [Alignment], which
  // has no directional variant and therefore never mirrors on its own. Without
  // these helpers the Skip button lands on top of the highlighted target in
  // Arabic and Persian instead of tucking into the opposite corner.
  static bool _isRtl(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl;

  static Alignment _skipTop(BuildContext context) =>
      _isRtl(context) ? Alignment.topLeft : Alignment.topRight;

  static Alignment _skipBottom(BuildContext context) =>
      _isRtl(context) ? Alignment.bottomLeft : Alignment.bottomRight;

  /// Creates the list of walkthrough targets in order.
  static List<TargetFocus> createTargets(BuildContext context) {
    return [
      // 1. FAB - Create Note (Most Important)
      TargetFocus(
        identify: 'fab_create_note',
        keyTarget: WalkthroughKeys.fabKey,
        alignSkip: _skipTop(context),
        enableOverlayTab: true,
        shape: ShapeLightFocus.Circle,
        paddingFocus: 10,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => WalkthroughTooltip(
              title: AppL10n.of(context).wtCreateTitle,
              description:
                  AppL10n.of(context).wtCreateBody,
              icon: Icons.add_rounded,
              accentColor: _mintColor,
              onNext: controller.next,
              showNextButton: true,
            ),
          ),
        ],
      ),

      // 2. Search Button
      TargetFocus(
        identify: 'search_button',
        keyTarget: WalkthroughKeys.searchKey,
        alignSkip: _skipBottom(context),
        enableOverlayTab: true,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => WalkthroughTooltip(
              title: AppL10n.of(context).wtSearchTitle,
              description:
                  AppL10n.of(context).wtSearchBody,
              icon: Icons.search_rounded,
              onNext: controller.next,
              showNextButton: true,
            ),
          ),
        ],
      ),

      // 3. Add Folder Button
      TargetFocus(
        identify: 'add_folder',
        keyTarget: WalkthroughKeys.addFolderKey,
        alignSkip: _skipBottom(context),
        enableOverlayTab: true,
        shape: ShapeLightFocus.RRect,
        radius: 10,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => WalkthroughTooltip(
              title: AppL10n.of(context).wtFoldersTitle,
              description:
                  AppL10n.of(context).wtFoldersBody,
              icon: Icons.create_new_folder_rounded,
              onNext: controller.next,
              showNextButton: true,
            ),
          ),
        ],
      ),

      // 4. Settings Nav Item (Last)
      TargetFocus(
        identify: 'nav_settings',
        keyTarget: WalkthroughKeys.navSettingsKey,
        alignSkip: _skipTop(context),
        enableOverlayTab: true,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => WalkthroughTooltip(
              title: AppL10n.of(context).wtSettingsTitle,
              description:
                  AppL10n.of(context).wtSettingsBody,
              icon: Icons.settings_rounded,
              onNext: controller.next,
              showNextButton: true,
              nextButtonText: AppL10n.of(context).wtDone,
            ),
          ),
        ],
      ),
    ];
  }
}
