import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/database.dart';
import '../../service_locators/init_service_locators.dart';
import '../backend_auth_service.dart';
import 'backup_archive.dart';
import 'backup_schedule.dart';
import 'drive_backup_client.dart';
import 'google_drive_authorization.dart';
import 'local_backup_service.dart';

/// Pinpoint's Google Drive backups, for every signed-in account, free or
/// premium: a rolling set of encrypted files in the user's own Drive, made by
/// hand or on a schedule, which can be restored (merged) onto any device
/// signed in to the same account.
///
/// Backups are encrypted with the account's key — the one cloud sync uses —
/// so only that account can open them, and signing in is required: a
/// signed-out device's key exists only on that device and would die with it.
///
/// Ported from The Accountant. Drive is a safety net next to cloud sync, not
/// a second sync: restoring is always something the user asks for.
class DriveBackupService extends ChangeNotifier {
  DriveBackupService._({DriveBackupClient? client, GoogleDriveAuthorization? authorization})
      : authorization = authorization ?? const GoogleDriveAuthorization(),
        _client = client ??
            DriveBackupClient(authorization: authorization ?? const GoogleDriveAuthorization());

  static final DriveBackupService _instance = DriveBackupService._();
  factory DriveBackupService() => _instance;

  @visibleForTesting
  factory DriveBackupService.forTesting(DriveBackupClient client) => DriveBackupService._(client: client);

  final GoogleDriveAuthorization authorization;
  final DriveBackupClient _client;

  LocalBackupService get _local => LocalBackupService(database: getIt<AppDatabase>());

  static const String frequencyKey = 'drive_backup_frequency';
  static const String keepKey = 'drive_backup_keep';
  static const String lastAtKey = 'drive_backup_last_at';
  static const String lastFailureKey = 'drive_backup_last_failure';

  /// A backup or restore in progress, so the screen and the automatic run do
  /// not start a second one.
  bool get busy => _busy;
  bool _busy = false;

  String? get _accountId {
    final auth = BackendAuthService();
    return auth.isAuthenticated ? auth.userId : null;
  }

  // ------------------------------------------------------------ schedule

  Future<BackupSchedule> readSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAt = prefs.getInt(lastAtKey);
    final failure = prefs.getString(lastFailureKey);
    return BackupSchedule(
      frequency: BackupFrequency.fromName(prefs.getString(frequencyKey)),
      keep: prefs.getInt(keepKey) ?? BackupSchedule.defaultKeep,
      lastBackupAt: lastAt == null ? null : DateTime.fromMillisecondsSinceEpoch(lastAt),
      lastFailure: BackupFailure.values.where((f) => f.name == failure).firstOrNull,
    );
  }

  Future<void> writeSchedule(BackupSchedule schedule) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(frequencyKey, schedule.frequency.name);
    await prefs.setInt(keepKey, schedule.keep);
    if (schedule.lastBackupAt != null) {
      await prefs.setInt(lastAtKey, schedule.lastBackupAt!.millisecondsSinceEpoch);
    }
    if (schedule.lastFailure == null) {
      await prefs.remove(lastFailureKey);
    } else {
      await prefs.setString(lastFailureKey, schedule.lastFailure!.name);
    }
    notifyListeners();
  }

  // --------------------------------------------------------------- files

  Future<List<DriveBackupFile>> list({bool interactive = false}) =>
      _client.list(interactive: interactive);

  Future<void> delete(String fileId) async {
    await _client.delete(fileId);
    notifyListeners();
  }

  /// Take a backup now and put it in Drive. Old backups are pruned only after
  /// the new one has landed.
  Future<DriveBackupFile> backupNow({bool interactive = true}) async {
    final account = _accountId;
    if (account == null) throw const DriveException(DriveProblem.needsAuthorization, 'signed out');
    if (_busy) throw const DriveException(DriveProblem.failed, 'busy');
    _busy = true;
    notifyListeners();
    File? file;
    try {
      final device = await deviceLabel();
      final created = await _local.create(
        accountId: account,
        appVersion: await _appVersion(),
        device: device,
      );
      file = created.file;
      final manifest = created.manifest;

      final uploaded = await _client.upload(
        file: file,
        name: fileNameFor(device: device, at: manifest.createdAt),
        mimeType: BackupArchive.mimeType,
        properties: {
          'format': '${manifest.formatVersion}',
          'account': account,
          'device': device,
          'notes': '${manifest.noteCount}',
          'recordings': '${manifest.recordingCount}',
        },
        interactive: interactive,
      );

      final schedule = await readSchedule();
      await writeSchedule(schedule.copyWith(lastBackupAt: manifest.createdAt, clearFailure: true));
      await pruneTo(schedule.keep, account: account, interactive: interactive);
      return uploaded;
    } finally {
      _busy = false;
      notifyListeners();
      try {
        await file?.delete();
      } catch (_) {}
    }
  }

  /// Remove this account's oldest backups until [keep] remain. A file that
  /// will not delete is skipped rather than stopping the sweep. Another
  /// account's backups in the same Drive are never counted or touched.
  Future<int> pruneTo(int keep, {required String account, bool interactive = false}) async {
    if (keep <= 0) return 0;
    final files = [
      for (final f in await _client.list(interactive: interactive))
        if (f.accountId == account) f,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    var removed = 0;
    for (final file in files.skip(keep)) {
      try {
        await _client.delete(file.id, interactive: false);
        removed++;
      } on DriveException {
        continue;
      }
    }
    return removed;
  }

  /// Download a backup and merge it into this device.
  Future<RestoreSummary> restoreFrom(DriveBackupFile backup) async {
    if (_busy) throw const DriveException(DriveProblem.failed, 'busy');
    _busy = true;
    notifyListeners();
    final file = File('${(await getTemporaryDirectory()).path}/restore-${backup.id}.${BackupArchive.fileExtension}');
    try {
      await _client.download(backup.id, file);
      return await _local.restore(file);
    } finally {
      _busy = false;
      notifyListeners();
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  /// Whether [file] was made by the signed-in account, judged from Drive's
  /// properties before anything is downloaded.
  bool isFromThisAccount(DriveBackupFile file) =>
      file.accountId == null || file.accountId == _accountId;

  bool _autoScheduled = false;

  /// Once per app session, shortly after startup: [runAutomaticIfDue].
  void scheduleAutomaticRun({Duration after = const Duration(seconds: 20)}) {
    if (_autoScheduled) return;
    _autoScheduled = true;
    Future<void>.delayed(after, runAutomaticIfDue);
  }

  /// Run the scheduled backup if one is owed. Never prompts: a lapsed grant
  /// skips the run and records why. True only when a backup went up.
  Future<bool> runAutomaticIfDue({DateTime? now}) async {
    if (_accountId == null || _busy) return false;
    final schedule = await readSchedule();
    if (!schedule.isDue(now ?? DateTime.now())) return false;
    try {
      await backupNow(interactive: false);
      debugPrint('☁️ [DriveBackup] Automatic backup done');
      return true;
    } on DriveException catch (e) {
      await writeSchedule(schedule.copyWith(lastFailure: failureFor(e.problem)));
      debugPrint('⚠️ [DriveBackup] Automatic backup skipped: $e');
      return false;
    } catch (e) {
      await writeSchedule(schedule.copyWith(lastFailure: BackupFailure.failed));
      debugPrint('⚠️ [DriveBackup] Automatic backup failed: $e');
      return false;
    }
  }

  static BackupFailure failureFor(DriveProblem problem) => switch (problem) {
        DriveProblem.needsAuthorization => BackupFailure.needsAuthorization,
        DriveProblem.offline => BackupFailure.offline,
        DriveProblem.storageFull => BackupFailure.storageFull,
        DriveProblem.notFound || DriveProblem.failed => BackupFailure.failed,
      };

  /// `pinpoint-backup-20261006-153000-samsung-sm-a245f.pinpoint-backup`: what
  /// and where from, readable in Drive without the app.
  static String fileNameFor({required String device, required DateTime at}) {
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${at.year}${two(at.month)}${two(at.day)}-${two(at.hour)}${two(at.minute)}${two(at.second)}';
    final safeDevice =
        device.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    final name = ['pinpoint-backup', stamp, if (safeDevice.isNotEmpty) safeDevice].join('-').toLowerCase();
    return '$name.${BackupArchive.fileExtension}';
  }

  /// "samsung SM-A245F", best effort: a blank label is better than no backup.
  static Future<String> deviceLabel() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        return '${a.manufacturer} ${a.model}'.trim();
      }
      if (Platform.isIOS) return (await info.iosInfo).name;
    } catch (_) {}
    return '';
  }

  static Future<String> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return '';
    }
  }
}
