import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Whatever can prove to Google that a request is being made by this user.
///
/// Behind an interface so the client can be exercised without a Google
/// account, and so the sign-in plugin is not a dependency of the transfers.
abstract class DriveAuthorization {
  /// Headers carrying an access token for [DriveBackupClient.scope], or null
  /// when it has not been granted and [interactive] does not allow asking.
  ///
  /// Automatic backups pass false: a consent screen thrown at somebody who
  /// just opened their notes is not acceptable, so a lapsed grant only means
  /// the automatic run is skipped until they next press the button.
  Future<Map<String, String>?> headers({bool interactive = false});
}

/// One backup file as Drive knows it.
class DriveBackupFile {
  const DriveBackupFile({
    required this.id,
    required this.name,
    required this.createdAt,
    this.sizeBytes,
    this.device,
    this.accountId,
    this.noteCount,
    this.formatVersion,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final int? sizeBytes;
  final String? device;

  /// The Pinpoint account whose key encrypted it, from Drive's properties, so
  /// a backup of another account can be marked in the list before download.
  final String? accountId;
  final int? noteCount;
  final int? formatVersion;

  factory DriveBackupFile.fromJson(Map<String, Object?> json) {
    final properties = json['appProperties'];
    final props = properties is Map ? properties : const {};
    return DriveBackupFile(
      id: '${json['id']}',
      name: '${json['name']}',
      createdAt: DateTime.tryParse('${json['createdTime']}')?.toLocal() ?? DateTime.now(),
      sizeBytes: int.tryParse('${json['size']}'),
      device: props['device'] as String?,
      accountId: props['account'] as String?,
      noteCount: int.tryParse('${props['notes']}'),
      formatVersion: int.tryParse('${props['format']}'),
    );
  }
}

enum DriveProblem {
  /// Access not granted, revoked, or the grant expired: ask again.
  needsAuthorization,

  /// No connection.
  offline,

  /// The user's Drive is full.
  storageFull,

  /// The file is gone.
  notFound,

  /// Anything else Google said no to.
  failed,
}

/// Something Drive would not do. The screen turns [problem] into words.
class DriveException implements Exception {
  const DriveException(this.problem, [this.detail]);

  final DriveProblem problem;

  /// Google's own message, for the log; never shown as is.
  final String? detail;

  bool get needsAuthorization => problem == DriveProblem.needsAuthorization;

  @override
  String toString() => 'DriveException($problem${detail == null ? '' : ': $detail'})';
}

/// The slice of the Drive API backups use, written against the REST endpoints
/// rather than the generated `googleapis` package, which would add megabytes
/// describing the rest of Drive. Ported from The Accountant.
class DriveBackupClient {
  DriveBackupClient({required DriveAuthorization authorization, http.Client? httpClient})
      : _authorization = authorization,
        _http = httpClient ?? http.Client();

  final DriveAuthorization _authorization;
  final http.Client _http;

  /// Per-file access: the app can only see files it created. Nothing else in
  /// the user's Drive is visible to it, so the listing below can query broadly.
  ///
  /// Chosen over `drive.appdata`, which hides backups where the user cannot
  /// see, copy or delete them without the app, and which Google classes as
  /// sensitive (a verification review). This scope is non-sensitive.
  static const String scope = 'https://www.googleapis.com/auth/drive.file';

  /// The folder backups go in, so they are somewhere obvious in Drive.
  static const String folderName = 'Pinpoint Backups';

  /// Marks our backups in Drive's app properties.
  static const String kindKey = 'kind';
  static const String kindValue = 'pinpoint-backup';

  static const String _folderMimeType = 'application/vnd.google-apps.folder';
  static const String _base = 'https://www.googleapis.com/drive/v3';
  static const String _uploadBase = 'https://www.googleapis.com/upload/drive/v3';
  static const String _fields = 'id,name,size,createdTime,appProperties';

  Future<Map<String, String>> _headers({required bool interactive}) async {
    final Map<String, String>? headers;
    try {
      headers = await _authorization.headers(interactive: interactive);
    } catch (e) {
      throw DriveException(DriveProblem.needsAuthorization, '$e');
    }
    if (headers == null) throw const DriveException(DriveProblem.needsAuthorization);
    return headers;
  }

  String? _folderId;

  /// The id of our folder, made on first use. Under this scope the search only
  /// sees folders this app made, so it cannot pick up one of the user's.
  Future<String> _folder({required bool interactive}) async {
    final cached = _folderId;
    if (cached != null) return cached;

    final query = Uri.encodeQueryComponent(
      "mimeType = '$_folderMimeType' and name = '$folderName' and trashed = false",
    );
    final found = await _send(
      (h) => _http.get(Uri.parse('$_base/files?q=$query&fields=files(id)&pageSize=1'), headers: h),
      interactive: interactive,
    );
    final body = jsonDecode(found.body);
    final files = body is Map ? body['files'] : null;
    if (files is List && files.isNotEmpty && files.first is Map) {
      return _folderId = '${(files.first as Map)['id']}';
    }

    final created = await _send(
      (h) => _http.post(
        Uri.parse('$_base/files?fields=id'),
        headers: {...h, 'Content-Type': 'application/json'},
        body: jsonEncode({'name': folderName, 'mimeType': _folderMimeType}),
      ),
      interactive: interactive,
    );
    final decoded = jsonDecode(created.body);
    if (decoded is! Map || decoded['id'] == null) {
      throw const DriveException(DriveProblem.failed, 'no folder id');
    }
    return _folderId = '${decoded['id']}';
  }

  /// Every backup this app has stored, newest first. Not restricted to the
  /// folder: a backup the user moved elsewhere in Drive is still found.
  Future<List<DriveBackupFile>> list({bool interactive = false}) async {
    final query = Uri.encodeQueryComponent(
      "appProperties has { key='$kindKey' and value='$kindValue' } and trashed = false",
    );
    final response = await _send(
      (h) => _http.get(
        Uri.parse('$_base/files?q=$query&orderBy=createdTime desc&pageSize=100&fields=files($_fields)'),
        headers: h,
      ),
      interactive: interactive,
    );
    final body = jsonDecode(response.body);
    final files = body is Map ? body['files'] : null;
    if (files is! List) return const [];
    return [
      for (final file in files)
        if (file is Map<String, Object?>) DriveBackupFile.fromJson(file),
    ];
  }

  /// Upload [file] as [name] with a resumable upload, streamed from disk so a
  /// backup holding recordings never has to fit in memory.
  Future<DriveBackupFile> upload({
    required File file,
    required String name,
    required String mimeType,
    Map<String, String> properties = const {},
    bool interactive = true,
  }) async {
    final length = await file.length();
    final metadata = jsonEncode({
      'name': name,
      'parents': [await _folder(interactive: interactive)],
      'mimeType': mimeType,
      'appProperties': {kindKey: kindValue, ...properties},
    });

    final session = await _send(
      (h) => _http.post(
        Uri.parse('$_uploadBase/files?uploadType=resumable&fields=$_fields'),
        headers: {
          ...h,
          'Content-Type': 'application/json; charset=UTF-8',
          'X-Upload-Content-Type': mimeType,
          'X-Upload-Content-Length': '$length',
        },
        body: metadata,
      ),
      interactive: interactive,
    );
    final location = session.headers['location'];
    if (location == null) throw const DriveException(DriveProblem.failed, 'no upload session');

    final response = await _send(
      (h) async {
        final request = http.StreamedRequest('PUT', Uri.parse(location))
          ..headers.addAll({...h, 'Content-Type': mimeType})
          ..contentLength = length;
        file.openRead().listen(request.sink.add,
            onDone: request.sink.close, onError: request.sink.addError);
        return http.Response.fromStream(await _http.send(request));
      },
      interactive: interactive,
    );

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const DriveException(DriveProblem.failed, 'no file in response');
    }
    return DriveBackupFile.fromJson(decoded);
  }

  /// Download a backup into [into].
  Future<void> download(String fileId, File into, {bool interactive = true}) async {
    final headers = await _headers(interactive: interactive);
    final http.StreamedResponse response;
    try {
      response = await _http.send(
          http.Request('GET', Uri.parse('$_base/files/$fileId?alt=media'))..headers.addAll(headers));
    } on SocketException {
      throw const DriveException(DriveProblem.offline);
    } on http.ClientException catch (e) {
      throw DriveException(DriveProblem.offline, e.message);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw _failure(response.statusCode, body);
    }
    final sink = into.openWrite();
    try {
      await response.stream.pipe(sink);
    } on SocketException {
      throw const DriveException(DriveProblem.offline);
    }
  }

  /// Remove a backup for good.
  Future<void> delete(String fileId, {bool interactive = true}) async {
    await _send((h) => _http.delete(Uri.parse('$_base/files/$fileId'), headers: h),
        interactive: interactive);
  }

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request, {
    required bool interactive,
  }) async {
    final headers = await _headers(interactive: interactive);
    final http.Response response;
    try {
      response = await request(headers);
    } on SocketException {
      throw const DriveException(DriveProblem.offline);
    } on http.ClientException catch (e) {
      throw DriveException(DriveProblem.offline, e.message);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _failure(response.statusCode, response.body);
    }
    return response;
  }

  static DriveException _failure(int status, String body) {
    final reason = _reason(body);
    if (status == 401) return DriveException(DriveProblem.needsAuthorization, reason);
    if (status == 403 && (reason?.contains('storageQuotaExceeded') ?? false)) {
      return DriveException(DriveProblem.storageFull, reason);
    }
    if (status == 403) return DriveException(DriveProblem.needsAuthorization, reason);
    if (status == 404) return DriveException(DriveProblem.notFound, reason);
    return DriveException(DriveProblem.failed, '$status ${reason ?? ''}');
  }

  /// Google's error reason and message, for telling a full Drive apart.
  static String? _reason(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        final error = decoded['error'] as Map;
        final errors = error['errors'];
        final reason = errors is List && errors.isNotEmpty && errors.first is Map
            ? (errors.first as Map)['reason']
            : null;
        return [reason, error['message']].whereType<String>().join(': ');
      }
    } catch (_) {
      // Not the error envelope; the status code speaks for itself.
    }
    return null;
  }
}
