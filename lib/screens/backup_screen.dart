import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../components/settings/settings_format.dart';
import '../components/settings/settings_widgets.dart';
import '../design_system/design_system.dart';
import '../navigation/app_navigation.dart';
import '../services/backend_auth_service.dart';
import '../services/backup/backup_archive.dart';
import '../services/backup/backup_schedule.dart';
import '../services/backup/drive_backup_client.dart';
import '../services/backup/drive_backup_service.dart';
import '../util/localized_dates.dart';
import '../util/show_a_toast.dart';
import 'auth_screen.dart';

/// Google Drive backups: connect Drive, back up now or on a schedule, and
/// restore (merge) or delete the backups already there. Free and Premium.
class BackupScreen extends StatefulWidget {
  static const String kRouteName = '/backup';

  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

enum _Busy { none, connecting, backingUp, restoring }

class _BackupScreenState extends State<BackupScreen> {
  final _service = DriveBackupService();
  final _auth = BackendAuthService();

  bool? _connected;
  BackupSchedule _schedule = const BackupSchedule();
  List<DriveBackupFile>? _files;
  _Busy _busy = _Busy.none;
  String? _listError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final schedule = await _service.readSchedule();
    final connected = _auth.isAuthenticated && await _service.authorization.isAuthorized();
    if (!mounted) return;
    setState(() {
      _schedule = schedule;
      _connected = connected;
    });
    if (connected) await _refreshList();
  }

  Future<void> _refreshList() async {
    try {
      final files = await _service.list();
      if (mounted) setState(() => (_files = files, _listError = null));
    } on DriveException catch (e) {
      if (mounted) setState(() => _listError = _driveMessage(e.problem));
    }
  }

  String _driveMessage(DriveProblem problem) {
    final l10n = AppL10n.of(context);
    return switch (problem) {
      DriveProblem.needsAuthorization => l10n.bkErrNeedsAuth,
      DriveProblem.offline => l10n.bkErrOffline,
      DriveProblem.storageFull => l10n.bkErrStorageFull,
      DriveProblem.notFound || DriveProblem.failed => l10n.bkErrFailed,
    };
  }

  String _failureMessage(BackupFailure failure) => _driveMessage(switch (failure) {
        BackupFailure.needsAuthorization => DriveProblem.needsAuthorization,
        BackupFailure.offline => DriveProblem.offline,
        BackupFailure.storageFull => DriveProblem.storageFull,
        BackupFailure.failed => DriveProblem.failed,
      });

  String _formatMessage(BackupProblem problem) {
    final l10n = AppL10n.of(context);
    return switch (problem) {
      BackupProblem.notABackup => l10n.bkErrNotABackup,
      BackupProblem.tooNew => l10n.bkErrTooNew,
      BackupProblem.otherAccount => l10n.bkErrOtherAccount,
    };
  }

  void _error(String message) {
    PinpointHaptics.error();
    showErrorToast(context: context, title: AppL10n.of(context).bkTitle, description: message);
  }

  Future<void> _connect() async {
    setState(() => _busy = _Busy.connecting);
    try {
      final granted = await _service.authorization.requestAccess();
      if (!mounted) return;
      setState(() => _connected = granted);
      if (granted) await _refreshList();
    } catch (_) {
      if (mounted) _error(AppL10n.of(context).bkErrNeedsAuth);
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
  }

  Future<void> _backupNow() async {
    final l10n = AppL10n.of(context);
    setState(() => _busy = _Busy.backingUp);
    try {
      final file = await _service.backupNow();
      if (!mounted) return;
      PinpointHaptics.success();
      showSuccessToast(
          context: context, title: l10n.bkTitle, description: l10n.bkBackupDone(file.noteCount ?? 0));
      _schedule = await _service.readSchedule();
      await _refreshList();
    } on DriveException catch (e) {
      if (!mounted) return;
      if (e.needsAuthorization) setState(() => _connected = false);
      _error(_driveMessage(e.problem));
    } catch (_) {
      if (mounted) _error(l10n.bkErrFailed);
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
  }

  Future<void> _restore(DriveBackupFile file) async {
    final l10n = AppL10n.of(context);
    final ok = await showSketchConfirm(
      context: context,
      title: l10n.bkRestoreConfirmTitle,
      message: l10n.bkRestoreConfirmBody(LocalizedDates.dateTime(context, file.createdAt)),
      confirmLabel: l10n.bkRestore,
      cancelLabel: l10n.commonCancel,
      destructive: false,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = _Busy.restoring);
    try {
      final summary = await _service.restoreFrom(file);
      if (!mounted) return;
      PinpointHaptics.success();
      showSuccessToast(
          context: context, title: l10n.bkTitle, description: l10n.bkRestoreDone(summary.notesAdded));
    } on BackupFormatException catch (e) {
      if (mounted) _error(_formatMessage(e.code));
    } on DriveException catch (e) {
      if (mounted) _error(_driveMessage(e.problem));
    } catch (_) {
      if (mounted) _error(l10n.bkErrFailed);
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
  }

  Future<void> _delete(DriveBackupFile file) async {
    final l10n = AppL10n.of(context);
    final ok = await showSketchConfirm(
      context: context,
      title: l10n.bkDeleteConfirmTitle,
      message: l10n.bkDeleteConfirmBody,
      confirmLabel: l10n.commonDelete,
      cancelLabel: l10n.commonCancel,
    );
    if (!ok || !mounted) return;
    try {
      await _service.delete(file.id);
      if (!mounted) return;
      showSuccessToast(context: context, title: l10n.bkTitle, description: l10n.bkDeleted);
      await _refreshList();
    } on DriveException catch (e) {
      if (mounted) _error(_driveMessage(e.problem));
    }
  }

  Future<void> _disconnect() async {
    try {
      await _service.authorization.revoke();
    } catch (_) {}
    if (!mounted) return;
    setState(() => (_connected = false, _files = null));
    showSuccessToast(
        context: context, title: AppL10n.of(context).bkTitle, description: AppL10n.of(context).bkDisconnected);
  }

  Future<void> _setSchedule(BackupSchedule schedule) async {
    PinpointHaptics.selection();
    setState(() => _schedule = schedule);
    await _service.writeSchedule(schedule);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final signedIn = _auth.isAuthenticated;

    return SketchScaffold(
      title: l10n.bkTitle,
      doodleTop: DoodleBackground.settingsTop,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.only(top: 18, bottom: 40 + bottom),
          children: [
            _pad(signedIn ? _statusCard(l10n) : _signedOutCard(l10n)),
            SketchOverline(l10n.bkHowTitle),
            _pad(SketchCard(
              radius: SketchRadius.group,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(children: [
                SketchBulletLine(text: l10n.bkHowEncrypted),
                SketchBulletLine(
                  text: l10n.bkHowAccountOnly(_auth.userEmail ?? ''),
                  color: SketchFunctional.error,
                ),
                SketchBulletLine(text: l10n.bkHowEverything),
                SketchBulletLine(text: l10n.bkHowMerge),
                SketchBulletLine(text: l10n.bkHowWhere),
              ]),
            )),
            if (signedIn && _connected == true) ...[
              SketchOverline(l10n.bkAutoTitle),
              _pad(_scheduleCard(l10n)),
              SketchOverline(l10n.bkListTitle),
              _list(l10n),
              const SizedBox(height: 16),
              SketchGroup(children: [
                SketchRow(
                  icon: Icons.link_off_rounded,
                  label: l10n.bkDisconnect,
                  labelColor: SketchFunctional.error,
                  onTap: _busy == _Busy.none ? _disconnect : null,
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pad(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: SketchSpace.screenX),
        child: child,
      );

  Widget _statusCard(AppL10n l10n) {
    final t = context.type;
    final s = context.sketch;
    final last = _schedule.lastBackupAt;
    final connected = _connected == true;
    final working = _busy == _Busy.backingUp || _busy == _Busy.restoring;

    return SketchCard(
      radius: SketchRadius.group,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(children: [
        StickerTile(
          color: last == null ? SketchPastels.sky : SketchPastels.mint,
          size: 88,
          angle: -6,
          shadowOffset: 4,
          icon: last == null ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined,
        ),
        const SizedBox(height: 18),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            switch (_busy) {
              _Busy.backingUp => l10n.bkBackingUp,
              _Busy.restoring => l10n.bkRestoring,
              _ => last == null ? l10n.bkStatusNever : l10n.bkStatusDone,
            },
            textAlign: TextAlign.center,
            style: t.emptyTitle,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          !connected && _connected != null
              ? l10n.bkStatusNotConnected
              : last == null
                  ? ''
                  : l10n.bkStatusLast(relativeAgo(context, last)),
          textAlign: TextAlign.center,
          style: t.bodySmall.copyWith(color: s.muted),
        ),
        if (_schedule.lastFailure != null && _schedule.isAutomatic) ...[
          const SizedBox(height: 12),
          SketchErrorPill(
              message: '${l10n.bkAutoFailed} ${_failureMessage(_schedule.lastFailure!)}'),
        ],
        const SizedBox(height: 20),
        if (_connected == null)
          const SizedBox(height: 52, child: Center(child: CircularProgressIndicator()))
        else if (!connected)
          PillButton(
            label: l10n.bkConnect,
            icon: Icons.add_to_drive_rounded,
            loading: _busy == _Busy.connecting,
            onPressed: _busy == _Busy.none ? _connect : null,
          )
        else
          PillButton(
            label: l10n.bkBackupNow,
            icon: Icons.backup_outlined,
            loading: working,
            onPressed: _busy == _Busy.none ? _backupNow : null,
          ),
      ]),
    );
  }

  Widget _signedOutCard(AppL10n l10n) {
    final t = context.type;
    return SketchCard(
      radius: SketchRadius.group,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(children: [
        const StickerTile(
            color: SketchPastels.lavender, size: 88, angle: -6, shadowOffset: 4, icon: Icons.lock_outline_rounded),
        const SizedBox(height: 18),
        Text(l10n.bkSignedOutTitle, textAlign: TextAlign.center, style: t.emptyTitle),
        const SizedBox(height: 8),
        Text(l10n.bkSignedOutBody, textAlign: TextAlign.center, style: t.bodySmall),
        const SizedBox(height: 20),
        PillButton(
          label: l10n.stSignInAction,
          icon: Icons.login_rounded,
          onPressed: () => AppNavigation.router.push(AuthScreen.kRouteName),
        ),
      ]),
    );
  }

  Widget _scheduleCard(AppL10n l10n) {
    final t = context.type;
    final s = context.sketch;
    String label(BackupFrequency f) => switch (f) {
          BackupFrequency.manual => l10n.bkFreqManual,
          BackupFrequency.daily => l10n.bkFreqDaily,
          BackupFrequency.weekly => l10n.bkFreqWeekly,
          BackupFrequency.monthly => l10n.bkFreqMonthly,
        };
    final count = NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag());
    return SketchCard(
      radius: SketchRadius.group,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in BackupFrequency.values)
            SketchChip(
              label: label(f),
              selected: _schedule.frequency == f,
              onTap: () => _setSchedule(_schedule.copyWith(frequency: f)),
            ),
        ]),
        const SizedBox(height: 10),
        Text(l10n.bkAutoNote, style: t.caption.copyWith(color: s.muted)),
        const SizedBox(height: 16),
        Text(l10n.bkKeepLabel, style: t.body),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final n in BackupSchedule.keepOptions)
            SketchChip(
              label: count.format(n),
              selected: _schedule.keep == n,
              onTap: () => _setSchedule(_schedule.copyWith(keep: n)),
            ),
        ]),
      ]),
    );
  }

  Widget _list(AppL10n l10n) {
    final files = _files;
    if (_listError != null) return _pad(SketchErrorPill(message: _listError!));
    if (files == null) {
      return const Padding(
          padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    }
    if (files.isEmpty) {
      return _pad(SketchCard(
        dashed: true,
        color: Colors.transparent,
        radius: SketchRadius.group,
        padding: const EdgeInsets.all(20),
        child: Text(l10n.bkListEmpty, textAlign: TextAlign.center, style: context.type.bodySmall),
      ));
    }
    final size = NumberFormat.decimalPatternDigits(
        locale: Localizations.localeOf(context).toLanguageTag(), decimalDigits: 1);
    return SketchGroup(children: [
      for (final file in files) _item(l10n, file, size),
    ]);
  }

  Widget _item(AppL10n l10n, DriveBackupFile file, NumberFormat size) {
    final mine = _service.isFromThisAccount(file);
    final details = [
      if ((file.device ?? '').isNotEmpty) file.device!,
      if (file.noteCount != null) l10n.bkItemNotes(file.noteCount!),
      if (file.sizeBytes != null) l10n.bkItemSize(size.format(file.sizeBytes! / (1024 * 1024))),
    ].join(' · ');
    final idle = _busy == _Busy.none;
    return SketchRow(
      icon: Icons.inventory_2_outlined,
      label: LocalizedDates.dateTime(context, file.createdAt),
      subtitle: mine ? details : l10n.bkItemOtherAccount,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (mine)
          CircleIconButton(
            icon: Icons.settings_backup_restore_rounded,
            semanticLabel: l10n.bkRestore,
            size: 38,
            onPressed: idle ? () => _restore(file) : null,
          ),
        const SizedBox(width: 6),
        CircleIconButton(
          icon: Icons.delete_outline_rounded,
          semanticLabel: l10n.commonDelete,
          size: 38,
          iconColor: SketchFunctional.error,
          onPressed: idle ? () => _delete(file) : null,
        ),
      ]),
    );
  }
}
