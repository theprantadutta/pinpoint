import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/components/create_note_screen/record_audio_type/voice_note_body.dart';
import 'package:pinpoint/services/audio_upload_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/project_source.dart';
import 'support/sketch_harness.dart';

/// Voice recordings reach the server through a queue that survives failures,
/// and only the server's path — never a file on this phone — is synced.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('server paths are told apart from files on a device', () {
    expect(AudioUploadQueue.isServerPath('3207b1a1-0bce-42b3-b85e-98454a81c593/9f1c1f3e-0000-4000-8000-000000000001.m4a'), isTrue);
    expect(AudioUploadQueue.isServerPath('/data/user/0/com.pranta.pinpoint/files/audio/x.m4a'), isFalse);
    // iOS app files live under /var — the old /data/ test took these for server paths.
    expect(AudioUploadQueue.isServerPath('/var/mobile/Containers/Data/Application/A/Documents/x.m4a'), isFalse);
    expect(AudioUploadQueue.isServerPath(''), isFalse);
  });

  test('a re-recording replaces the queued file and forgets the old server copy', () async {
    await AudioUploadQueue.setRemotePath('n1', 'old/server.m4a');
    await AudioUploadQueue.enqueue('n1', '/data/a.m4a');
    await AudioUploadQueue.enqueue('n1', '/data/b.m4a');

    expect(await AudioUploadQueue.pending(), [
      {'uuid': 'n1', 'path': '/data/b.m4a'},
    ]);
    expect((await AudioUploadQueue.remotePaths()).containsKey('n1'), isFalse);
  });

  test('sync sends the server path, retries uploads, and keeps the local file', () {
    final sync = readProjectFile('lib/sync/api_sync_service.dart');
    expect(sync, contains("remotePaths[note.uuid]"));
    expect(sync, isNot(contains("startsWith('/data/')")));
    expect(readProjectFile('lib/sync/sync_manager.dart'), contains('AudioUploadQueue.process()'));
    final voice = readProjectFile('lib/services/voice_note_service.dart');
    expect(voice, contains('AudioUploadQueue.enqueue(noteUuid, audioFilePath)'));
    expect(voice, contains('AudioUploadQueue.enqueue(note.uuid, audioFilePath)'));
  });

  test('the cloud limit sits under the server cap, with room for framing', () {
    const serverCap = 25 * 1024 * 1024;
    expect(AudioUploadQueue.fitsCloud(20 * 1024 * 1024), isTrue);
    expect(AudioUploadQueue.fitsCloud(AudioUploadQueue.maxUploadBytes), isTrue);
    expect(AudioUploadQueue.fitsCloud(AudioUploadQueue.maxUploadBytes + 1), isFalse);
    expect(AudioUploadQueue.maxUploadBytes, lessThan(serverCap));
  });

  testWidgets('an oversized recording says it stays on this device', (tester) async {
    Widget body({int? tooLarge}) => sketchApp(SingleChildScrollView(
          child: VoiceNoteBody(
            recording: false,
            recorded: Duration.zero,
            hasAudio: true,
            playing: false,
            position: Duration.zero,
            total: const Duration(minutes: 31),
            onRecord: () {},
            onPlay: () {},
            onPause: () {},
            onStop: () {},
            onReplace: () {},
            onSeek: (_) {},
            tooLargeToSyncMegabytes: tooLarge,
          ),
        ));

    await tester.pumpWidget(body());
    expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);

    await tester.pumpWidget(body(tooLarge: 25));
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(find.textContaining('Over 25 MB'), findsOneWidget);
  });
}
