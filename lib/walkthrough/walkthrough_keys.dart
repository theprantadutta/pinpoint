import 'package:flutter/material.dart';

/// Centralized registry for walkthrough target GlobalKeys.
/// Widgets register their keys here, and the walkthrough service reads them.
class WalkthroughKeys {
  WalkthroughKeys._();

  // Navigation elements
  static final GlobalKey fabKey = GlobalKey(debugLabel: 'fab_create_note');
  static final GlobalKey navSettingsKey = GlobalKey(debugLabel: 'nav_settings');

  // Home screen elements
  static final GlobalKey addFolderKey = GlobalKey(debugLabel: 'add_folder');
  static final GlobalKey searchKey = GlobalKey(debugLabel: 'search_button');
}
