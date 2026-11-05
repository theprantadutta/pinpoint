import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:quick_actions/quick_actions.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../generated/l10n/app_localizations.dart';
import '../../navigation/new_note.dart';

/// Something to write down that arrived from outside the app.
class Capture {
  const Capture({
    required this.source,
    this.noteType = NewNote.text,
    this.text,
    this.files = const [],
  });

  /// `share` or `shortcut`, for analytics.
  final String source;
  final String noteType;
  final String? text;
  final List<({String path, String name})> files;
}

/// Holds what the share sheet or a home screen shortcut sent until the app is
/// ready for it. Only the home shell takes from here, and the shell is built
/// after sign-in and the unlock screen, so neither route gets past the lock.
class CaptureInbox {
  CaptureInbox._();

  static final ValueNotifier<Capture?> pending = ValueNotifier(null);

  static const String _checklistShortcut = 'new_checklist';
  static const String _voiceShortcut = 'new_voice';
  static const String _noteShortcut = 'new_note';

  static const QuickActions _quickActions = QuickActions();
  static const MethodChannel _readyChannel =
      MethodChannel('com.pranta.pinpoint/capture');
  static bool _started = false;

  static Capture? take() {
    final capture = pending.value;
    pending.value = null;
    return capture;
  }

  static Future<void> start() async {
    if (_started || !(Platform.isAndroid || Platform.isIOS)) return;
    _started = true;
    try {
      await _quickActions.initialize(_onShortcut);
      // The iOS share sheet needs a Share Extension target, which is not
      // built yet.
      if (!Platform.isAndroid) return;
      final sharing = ReceiveSharingIntent.instance;
      sharing.getMediaStream().listen(_onShared);
      _onShared(await sharing.getInitialMedia());
    } catch (e) {
      debugPrint('⚠️ [CaptureInbox] Could not start: $e');
    } finally {
      // Releases anything the activity held back until Dart was listening.
      if (Platform.isAndroid) {
        try {
          await _readyChannel.invokeMethod<void>('ready');
        } catch (e) {
          debugPrint('⚠️ [CaptureInbox] Could not report ready: $e');
        }
      }
    }
  }

  /// Titles are localized, so this runs from the widget tree. Cheap to repeat.
  static Future<void> setShortcuts(AppL10n l10n) async {
    if (!_started) return;
    String? icon(String name) => Platform.isAndroid ? name : null;
    try {
      await _quickActions.setShortcutItems([
        ShortcutItem(
            type: _noteShortcut,
            localizedTitle: l10n.dockNewNote,
            icon: icon('ic_shortcut_note')),
        ShortcutItem(
            type: _checklistShortcut,
            localizedTitle: l10n.noteTypeChecklist,
            icon: icon('ic_shortcut_checklist')),
        ShortcutItem(
            type: _voiceShortcut,
            localizedTitle: l10n.noteTypeVoice,
            icon: icon('ic_shortcut_voice')),
      ]);
    } catch (e) {
      debugPrint('⚠️ [CaptureInbox] Could not set shortcuts: $e');
    }
  }

  static void _onShortcut(String type) {
    pending.value = fromShortcut(type);
  }

  static void _onShared(List<SharedMediaFile> shared) {
    final capture = fromShared(shared);
    if (capture == null) return;
    pending.value = capture;
    unawaited(ReceiveSharingIntent.instance.reset());
  }

  @visibleForTesting
  static Capture fromShortcut(String type) => Capture(
        source: 'shortcut',
        noteType: switch (type) {
          _checklistShortcut => NewNote.checklist,
          _voiceShortcut => NewNote.voice,
          _ => NewNote.text,
        },
      );

  /// Text and links go in the note body, anything else becomes an attachment.
  @visibleForTesting
  static Capture? fromShared(List<SharedMediaFile> shared) {
    bool isText(SharedMediaFile f) =>
        f.type == SharedMediaType.text || f.type == SharedMediaType.url;
    final text = [
      for (final f in shared)
        if (isText(f) && f.path.trim().isNotEmpty) f.path.trim(),
    ].join('\n');
    final files = [
      for (final f in shared)
        if (!isText(f)) (path: f.path, name: p.basename(f.path)),
    ];
    if (text.isEmpty && files.isEmpty) return null;
    return Capture(
      source: 'share',
      text: text.isEmpty ? null : text,
      files: files,
    );
  }
}
