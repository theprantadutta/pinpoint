import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../navigation/app_navigation.dart';
import '../../screens/admin_panel_screen.dart';
import '../../screens/archive_screen.dart';
import '../../screens/display_screen.dart';
import '../../screens/language_screen.dart';
import '../../screens/sync_debug_screen.dart';
import '../../screens/sync_screen.dart';
import '../../screens/terms_acceptance_screen.dart';
import '../../screens/trash_screen.dart';
import '../../services/app_review_service.dart';
import '../../services/backend_auth_service.dart';
import '../../services/drift_note_service.dart';
import '../../services/firebase_notification_service.dart';
import '../../services/locale_controller.dart';
import '../../services/walkthrough_service.dart';
import '../../util/show_a_toast.dart';
import '../../widgets/admin_password_dialog.dart';
import 'settings_about_sheet.dart';

/// The admin identity. Matches the server's ADMIN_EMAIL; the admin panel
/// itself is still behind its own password.
const String kSettingsAdminEmail = 'prantadutta1997@gmail.com';

/// GENERAL: language, display, notifications.
class SettingsGeneralGroup extends StatefulWidget {
  const SettingsGeneralGroup({super.key});

  @override
  State<SettingsGeneralGroup> createState() => _SettingsGeneralGroupState();
}

class _SettingsGeneralGroupState extends State<SettingsGeneralGroup>
    with WidgetsBindingObserver {
  bool? _notificationsOn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from the system settings page is the moment the answer can
  // change.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _readNotifications();
  }

  Future<void> _readNotifications() async {
    bool on;
    try {
      on = await Permission.notification.isGranted;
    } catch (_) {
      on = false;
    }
    if (mounted) setState(() => _notificationsOn = on);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = context.watch<LocaleController>().locale;

    return SketchGroup(
      children: [
        SketchRow(
          label: l10n.settingsLanguageTitle,
          value: locale == null
              ? l10n.languageSystemDefault
              : LocaleController.displayName(locale),
          onTap: () {
            PinpointHaptics.medium();
            AppNavigation.router.push(LanguageScreen.kRouteName);
          },
        ),
        SketchRow(
          label: l10n.setDisplay,
          subtitle: l10n.setDisplaySubtitle,
          onTap: () {
            PinpointHaptics.medium();
            AppNavigation.router.push(DisplayScreen.kRouteName);
          },
        ),
        SketchRow(
          label: l10n.stNotifications,
          value: _notificationsOn == null
              ? null
              : (_notificationsOn! ? l10n.stOn : l10n.stOff),
          chevron: true,
          onTap: () {
            PinpointHaptics.medium();
            openAppSettings();
          },
        ),
      ],
    );
  }
}

/// NOTES: folders, archive, trash, sync and importing a note.
class SettingsNotesGroup extends StatelessWidget {
  const SettingsNotesGroup({super.key});

  Future<void> _importNote(BuildContext context) async {
    PinpointHaptics.medium();
    final l10n = AppL10n.of(context);
    // file_picker 12 returns a list from pickFiles() and defaults
    // allowMultiple to true; pickFile() is the single-selection API, which is
    // what importing one note actually wants.
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pinpoint-note'],
    );
    if (picked == null) return;
    final path = picked.path;
    if (path == null) return;

    // Android's system picker does not reliably honor allowedExtensions, so
    // users can select any file. Guard against non-.pinpoint-note files (e.g.
    // an audio recording) whose binary contents can't be decoded as UTF-8.
    // file_picker 12 dropped PlatformFile.extension; `name` carries the
    // extension, and it survives Android's SAF copy better than the temp
    // `path` does, so it is checked first.
    final isValidExtension =
        picked.name.toLowerCase().endsWith('.pinpoint-note') ||
            path.toLowerCase().endsWith('.pinpoint-note');
    if (!isValidExtension) {
      if (context.mounted) {
        PinpointHaptics.error();
        showErrorToast(
          context: context,
          title: l10n.setUnsupportedFile,
          description: l10n.setUnsupportedFileBody,
        );
      }
      return;
    }
    try {
      final jsonString = await File(path).readAsString();
      await DriftNoteService.importNoteFromJson(jsonString);
      if (context.mounted) {
        PinpointHaptics.success();
        showSuccessToast(
          context: context,
          title: l10n.setNoteImported,
          description: l10n.setNoteImportedBody,
        );
      }
    } catch (e) {
      if (context.mounted) {
        PinpointHaptics.error();
        showErrorToast(
          context: context,
          title: l10n.setImportFailed,
          description: l10n.setUnsupportedFileBody,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    void go(String route) {
      PinpointHaptics.medium();
      AppNavigation.router.push(route);
    }

    return SketchGroup(
      children: [
        SketchRow(
          icon: Icons.folder_outlined,
          label: l10n.stMyFolders,
          onTap: () => go('/my-folders'),
        ),
        SketchRow(
          icon: Icons.archive_outlined,
          label: l10n.setArchive,
          onTap: () => go(ArchiveScreen.kRouteName),
        ),
        SketchRow(
          icon: Icons.delete_outline_rounded,
          label: l10n.setTrash,
          onTap: () => go(TrashScreen.kRouteName),
        ),
        SketchRow(
          icon: Icons.sync_rounded,
          label: l10n.syncTitle,
          onTap: () => go(SyncScreen.kRouteName),
        ),
        SketchRow(
          icon: Icons.file_upload_outlined,
          label: l10n.stImportNote,
          subtitle: l10n.setImportNoteSubtitle,
          onTap: () => _importNote(context),
        ),
      ],
    );
  }
}

/// HELP & LEGAL: tutorial, rating, terms and the About sheet with version.
class SettingsHelpGroup extends StatefulWidget {
  const SettingsHelpGroup({super.key});

  @override
  State<SettingsHelpGroup> createState() => _SettingsHelpGroupState();
}

class _SettingsHelpGroupState extends State<SettingsHelpGroup> {
  String? _version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    }).catchError((_) {});
  }

  Future<void> _replayTutorial() async {
    PinpointHaptics.medium();
    // Reset walkthrough so it will show again
    await WalkthroughService().resetWalkthrough();
    if (!mounted) return;

    // Return to the home screen first (settings is a pushed route)
    Navigator.of(context).pop();

    // Delay then show walkthrough
    final ctx = context;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (ctx.mounted) WalkthroughService().showWalkthrough(ctx);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return SketchGroup(
      children: [
        SketchRow(
          label: l10n.stReplayTutorial,
          onTap: _replayTutorial,
        ),
        SketchRow(
          label: l10n.setRateApp,
          onTap: () {
            PinpointHaptics.medium();
            AppReviewService().openStoreListing();
          },
        ),
        SketchRow(
          label: l10n.stTermsPrivacy,
          onTap: () {
            PinpointHaptics.medium();
            AppNavigation.router.push(
              TermsAcceptanceScreen.kRouteName,
              extra: true, // isViewOnly = true
            );
          },
        ),
        SketchRow(
          label: l10n.setAboutApp,
          value: _version == null ? null : l10n.stVersionShort(_version!),
          chevron: true,
          onTap: () {
            PinpointHaptics.medium();
            showSettingsAboutSheet(context);
          },
        ),
      ],
    );
  }
}

/// Debug-build and admin-only tools. English by design, like the admin
/// screens they open.
class SettingsDeveloperGroup extends StatelessWidget {
  const SettingsDeveloperGroup({super.key});

  static bool visible(BuildContext context) =>
      kDebugMode ||
      context.read<BackendAuthService>().userEmail == kSettingsAdminEmail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final isAdmin =
        context.read<BackendAuthService>().userEmail == kSettingsAdminEmail;
    final authenticated = context.read<BackendAuthService>().isAuthenticated;

    return SketchGroup(
      children: [
        if (kDebugMode && authenticated)
          SketchRow(
            icon: Icons.bug_report_outlined,
            label: l10n.setSyncDebug,
            subtitle: l10n.setSyncDebugSubtitle,
            onTap: () {
              PinpointHaptics.medium();
              AppNavigation.router.push(SyncDebugScreen.kRouteName);
            },
          ),
        if (kDebugMode)
          SketchRow(
            icon: Icons.notifications_active_outlined,
            label: l10n.setTestNotification,
            subtitle: l10n.setTestNotificationSubtitle,
            onTap: () async {
              PinpointHaptics.medium();
              try {
                await FirebaseNotificationService().sendTestNotification();
                if (context.mounted) {
                  showSuccessToast(
                    context: context,
                    title: l10n.setTestNotification,
                    description: l10n.setCheckNotificationTray,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  showErrorToast(
                    context: context,
                    title: l10n.setFailedTitle,
                    description: e.toString(),
                  );
                }
              }
            },
          ),
        if (kDebugMode)
          SketchRow(
            icon: Icons.warning_amber_rounded,
            label: l10n.setTestCrash,
            subtitle: l10n.setTestCrashSubtitle,
            onTap: () {
              PinpointHaptics.medium();
              FirebaseCrashlytics.instance.crash();
            },
          ),
        if (isAdmin)
          SketchRow(
            icon: Icons.admin_panel_settings_outlined,
            label: l10n.setAdminPanel,
            subtitle: l10n.setAdminPanelSubtitle,
            onTap: () async {
              PinpointHaptics.medium();
              final authenticated = await showDialog<bool>(
                context: context,
                builder: (context) => const AdminPasswordDialog(),
              );
              if (authenticated == true && context.mounted) {
                AppNavigation.router.push(AdminPanelScreen.kRouteName);
              }
            },
          ),
      ],
    );
  }
}
