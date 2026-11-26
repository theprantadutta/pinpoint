import 'dart:async';
import 'dart:io';

import '../services/api_service.dart';

/// Every value [syncFailureReason] can return: the `reason` of `sync_failed`.
///
/// - `offline`: no route to the server (no network, DNS, refused, dropped).
/// - `timeout`: the connection, the upload or the answer took too long.
/// - `unauthorized`: the session was refused (401).
/// - `limit`: a plan limit stopped the sync.
/// - `rate_limited`: the server asked us to slow down (429).
/// - `encryption_key`: the account key is not available on this device yet.
/// - `rejected`: the server answered with any other 4xx.
/// - `server_error`: the server, or Cloudflare in front of it, answered 5xx.
/// - `unknown`: anything else, such as a local database or decoding error.
const Set<String> syncFailureReasons = {
  'offline',
  'timeout',
  'unauthorized',
  'limit',
  'rate_limited',
  'encryption_key',
  'rejected',
  'server_error',
  'unknown',
};

/// A sync failure as a closed code for analytics (see [syncFailureReasons]).
/// Error text can carry note titles, paths or server messages, so it is never
/// sent (review 2026-11-01, F8). Pure, for testing.
///
/// Classified by the error's type and HTTP status first. Until Nov 2026 it
/// read the text only, and ApiService's "Unable to connect to server." (no
/// network) and "Server is taking too long to respond." both contained
/// "server": nearly every `server_error` was a phone without a connection,
/// while real 500s ("Something went wrong on our end.") came out `unknown`.
/// Text is still read for results that carry no error object.
String syncFailureReason(Object? error) {
  if (error is ApiError) return _fromApiError(error);
  if (error is RateLimitExceededException) return 'rate_limited';
  if (error is SocketException || error is HttpException || error is HandshakeException) {
    return 'offline';
  }
  if (error is TimeoutException) return 'timeout';
  return _fromText('$error'.toLowerCase());
}

String _fromApiError(ApiError error) {
  switch (error.type) {
    case ApiErrorType.network:
      return 'offline';
    case ApiErrorType.timeout:
      return 'timeout';
    case ApiErrorType.unauthorized:
      return 'unauthorized';
    case ApiErrorType.rateLimit:
      return 'rate_limited';
    case ApiErrorType.serverError:
    case ApiErrorType.maintenance:
      return 'server_error';
    case ApiErrorType.forbidden:
    case ApiErrorType.notFound:
    case ApiErrorType.conflict:
    case ApiErrorType.unknown:
      final status = error.statusCode;
      if (status == null) return 'unknown';
      if (status >= 500) return 'server_error';
      if (status == 401) return 'unauthorized';
      if (status == 429) return 'rate_limited';
      if (status >= 400) return 'rejected';
      return 'unknown';
  }
}

final RegExp _http5xx = RegExp(r'\b5\d\d\b');

String _fromText(String text) {
  // First: the key message also tells the user to check the connection.
  if (text.contains('encryption key')) return 'encryption_key';
  if (text.contains('timed out') || text.contains('timeout') || text.contains('taking too long')) {
    return 'timeout';
  }
  if (text.contains('socket') || text.contains('connection') || text.contains('unable to connect') ||
      text.contains('offline') || text.contains('network') || text.contains('host lookup')) {
    return 'offline';
  }
  if (text.contains('401') || text.contains('unauthor') || text.contains('session')) return 'unauthorized';
  if (text.contains('too many requests') || text.contains('429')) return 'rate_limited';
  if (text.contains('limit') || text.contains('premium')) return 'limit';
  // A status code or the server's own words, never a bare "server": every
  // ApiService transport message names the server too.
  if (_http5xx.hasMatch(text) || text.contains('server error') || text.contains('went wrong on our end') ||
      text.contains('temporarily unavailable')) {
    return 'server_error';
  }
  return 'unknown';
}
