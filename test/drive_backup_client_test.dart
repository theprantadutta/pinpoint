import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pinpoint/services/backup/drive_backup_client.dart';
import 'package:pinpoint/services/backup/drive_backup_service.dart';

class _Granted implements DriveAuthorization {
  @override
  Future<Map<String, String>?> headers({bool interactive = false}) async =>
      {'Authorization': 'Bearer test'};
}

class _NotGranted implements DriveAuthorization {
  @override
  Future<Map<String, String>?> headers({bool interactive = false}) async => null;
}

/// The Drive REST calls, against a fake Google.
void main() {
  test('upload is resumable: a session, then the file streamed to it', () async {
    final calls = <String>[];
    late List<int> uploaded;
    final client = DriveBackupClient(
      authorization: _Granted(),
      httpClient: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}?${request.url.query}');
        if (request.url.path == '/drive/v3/files' && request.method == 'GET') {
          return http.Response(jsonEncode({'files': [{'id': 'folder-1'}]}), 200);
        }
        if (request.url.query.contains('uploadType=resumable')) {
          final meta = jsonDecode(request.body) as Map;
          expect(meta['parents'], ['folder-1']);
          expect((meta['appProperties'] as Map)['kind'], 'pinpoint-backup');
          expect(request.headers['X-Upload-Content-Length'], '5');
          return http.Response('', 200, headers: {'location': 'https://upload.test/session-1'});
        }
        if (request.method == 'PUT') {
          expect(request.url.toString(), 'https://upload.test/session-1');
          uploaded = request.bodyBytes;
          return http.Response(jsonEncode({
            'id': 'file-1', 'name': 'b.pinpoint-backup', 'size': '5',
            'createdTime': '2026-10-06T09:00:00Z',
            'appProperties': {'account': 'acct', 'notes': '3', 'format': '1'},
          }), 200);
        }
        return http.Response('unexpected', 500);
      }),
    );

    final dir = await Directory.systemTemp.createTemp('pp_drive');
    final file = File('${dir.path}/b.pinpoint-backup')..writeAsBytesSync([1, 2, 3, 4, 5]);
    final result = await client.upload(file: file, name: 'b.pinpoint-backup', mimeType: 'application/zip');
    await dir.delete(recursive: true);

    expect(uploaded, [1, 2, 3, 4, 5]);
    expect(result.id, 'file-1');
    expect(result.accountId, 'acct');
    expect(result.noteCount, 3);
    expect(calls.where((c) => c.startsWith('PUT')), hasLength(1));
  });

  test('a listing only asks for our backups', () async {
    late Uri asked;
    final client = DriveBackupClient(
      authorization: _Granted(),
      httpClient: MockClient((request) async {
        asked = request.url;
        return http.Response(jsonEncode({'files': []}), 200);
      }),
    );
    await client.list();
    expect(asked.queryParameters['q'], contains("appProperties has { key='kind' and value='pinpoint-backup' }"));
  });

  test('refusals become problems the screen can explain', () async {
    Future<DriveProblem> problemFor(int status, Map<String, Object?> body) async {
      final client = DriveBackupClient(
        authorization: _Granted(),
        httpClient: MockClient((_) async => http.Response(jsonEncode(body), status)),
      );
      try {
        await client.list();
        fail('should throw');
      } on DriveException catch (e) {
        return e.problem;
      }
    }

    final full = {
      'error': {
        'message': 'The user\'s Drive storage quota has been exceeded.',
        'errors': [{'reason': 'storageQuotaExceeded'}],
      }
    };
    expect(await problemFor(403, full), DriveProblem.storageFull);
    expect(await problemFor(401, {}), DriveProblem.needsAuthorization);
    expect(await problemFor(403, {'error': {'message': 'Insufficient Permission'}}), DriveProblem.needsAuthorization);
    expect(await problemFor(404, {}), DriveProblem.notFound);
    expect(await problemFor(500, {}), DriveProblem.failed);
  });

  test('no grant, no request', () async {
    var requested = false;
    final client = DriveBackupClient(
      authorization: _NotGranted(),
      httpClient: MockClient((_) async {
        requested = true;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(client.list(), throwsA(isA<DriveException>().having((e) => e.needsAuthorization, 'auth', isTrue)));
    expect(requested, isFalse);
  });

  test('pruning keeps the newest of this account and never touches another account', () async {
    Map<String, Object?> file(String id, String account, int day) => {
          'id': id, 'name': '$id.pinpoint-backup',
          'createdTime': '2026-10-${day.toString().padLeft(2, '0')}T09:00:00Z',
          'appProperties': {'account': account},
        };
    final deleted = <String>[];
    final client = DriveBackupClient(
      authorization: _Granted(),
      httpClient: MockClient((request) async {
        if (request.method == 'DELETE') {
          deleted.add(request.url.pathSegments.last);
          return http.Response('', 204);
        }
        return http.Response(jsonEncode({'files': [
          file('a4', 'mine', 4), file('a3', 'mine', 3), file('x9', 'other', 9),
          file('a2', 'mine', 2), file('x1', 'other', 1), file('a1', 'mine', 1),
        ]}), 200);
      }),
    );
    final removed = await DriveBackupService.forTesting(client).pruneTo(2, account: 'mine');
    expect(removed, 2);
    expect(deleted, unorderedEquals(['a2', 'a1']));
  });
}
