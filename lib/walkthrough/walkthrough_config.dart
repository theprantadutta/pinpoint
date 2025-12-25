import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'walkthrough_keys.dart';
import 'walkthrough_content.dart';

/// Configuration for walkthrough targets.
/// Defines the order, content, and appearance of each coach mark.
class WalkthroughConfig {
  WalkthroughConfig._();

  /// Mint color used in the app's primary accent
  static const Color _mintColor = Color(0xFF4ECCA3);

  /// Creates the list of walkthrough targets in order.
  static List<TargetFocus> createTargets(BuildContext context) {
    return [
      // 1. FAB - Create Note (Most Important)
      TargetFocus(
        identify: 'fab_create_note',
        keyTarget: WalkthroughKeys.fabKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        shape: ShapeLightFocus.Circle,
        paddingFocus: 10,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => WalkthroughTooltip(
              title: 'Create a Note',
              description:
                  'Tap here to create a new note. You can add text, voice recordings, todo lists, and reminders!',
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
        alignSkip: Alignment.bottomRight,
        enableOverlayTab: true,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => WalkthroughTooltip(
              title: 'Search Notes',
              description:
                  'Quickly find any note by searching through titles and content.',
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
        alignSkip: Alignment.bottomRight,
        enableOverlayTab: true,
        shape: ShapeLightFocus.RRect,
        radius: 10,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => WalkthroughTooltip(
              title: 'Organize with Folders',
              description:
                  'Create folders to keep your notes organized by topic, project, or category.',
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
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => WalkthroughTooltip(
              title: 'Settings & More',
              description:
                  'Access settings, sync options, and customize your experience. You can replay this tutorial anytime from here!',
              icon: Icons.settings_rounded,
              onNext: controller.next,
              showNextButton: true,
              nextButtonText: 'Done',
            ),
          ),
        ],
      ),
    ];
  }
}
