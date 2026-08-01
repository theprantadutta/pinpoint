import 'package:flutter/widgets.dart';

import '../generated/l10n/app_localizations.dart';
import '../services/api_service.dart';

/// Renders a server [ApiError] in the user's language.
///
/// The backend deliberately does not translate error prose. It returns a stable
/// code (`app/core/errors.py`) and this table turns that code into localized
/// copy, so there is exactly one translation pipeline — the client's ARB files —
/// and a response that was queued offline still surfaces in the right language
/// whenever it is finally shown.
///
/// Codes with no entry here fall back to the server's English `message`. That is
/// intentional: the backend can add a code and ship it before the app knows
/// about it, and the user sees imperfect-but-correct text rather than nothing.
String localizedApiError(BuildContext context, ApiError error) {
  final code = error.errorCode;
  if (code != null) {
    final mapped = _messageForCode(AppL10n.of(context), code);
    if (mapped != null) return mapped;
  }
  // No code, or a code this build does not know: fall back to the transport
  // classification, which still beats the service's English literal.
  return localizedTransportError(context, error).message;
}

/// Same as [localizedApiError] but for a bare code string.
String? localizedErrorCode(BuildContext context, String code) =>
    _messageForCode(AppL10n.of(context), code);

String? _messageForCode(AppL10n l10n, String code) {
  switch (code) {
    // --- Authentication / session -----------------------------------------
    case 'INVALID_CREDENTIALS':
      return l10n.errInvalidCredentials;
    case 'EMAIL_ALREADY_REGISTERED':
      return l10n.errEmailAlreadyRegistered;
    case 'INVALID_AUTH_CREDENTIALS':
    case 'INVALID_REFRESH_TOKEN':
    case 'INVALID_REFRESH_TOKEN_PAYLOAD':
      // All three mean the same thing to a user: sign in again.
      return l10n.errSessionExpired;
    case 'USER_NOT_FOUND':
      return l10n.errUserNotFound;
    case 'USER_INACTIVE':
      return l10n.errUserInactive;
    case 'ACCOUNT_DELETE_FAILED':
      return l10n.errAccountDeleteFailed;

    // --- Federated sign-in --------------------------------------------------
    case 'INVALID_FIREBASE_TOKEN':
    case 'FIREBASE_INIT_ERROR':
    case 'AUTHENTICATION_FAILED':
      return l10n.errAuthenticationFailed;
    case 'ACCOUNT_REQUIRES_LINKING':
      return l10n.errAccountRequiresLinking;
    case 'ACCOUNT_HAS_NO_PASSWORD':
      return l10n.errAccountHasNoPassword;
    case 'INCORRECT_PASSWORD':
      return l10n.errIncorrectPassword;
    case 'GOOGLE_ACCOUNT_ALREADY_LINKED':
      return l10n.errGoogleAccountAlreadyLinked;
    case 'ACCOUNT_LINKING_FAILED':
      return l10n.errAccountLinkingFailed;
    case 'CANNOT_UNLINK_WITHOUT_PASSWORD':
      return l10n.errCannotUnlinkWithoutPassword;
    case 'NO_GOOGLE_ACCOUNT_LINKED':
      return l10n.errNoGoogleAccountLinked;

    // --- Authorization -------------------------------------------------------
    case 'ACCESS_DENIED':
      return l10n.errAccessDenied;
    case 'PREMIUM_REQUIRED':
      return l10n.errPremiumRequired;

    // --- Encryption ----------------------------------------------------------
    case 'ENCRYPTION_KEY_NOT_FOUND':
    case 'NO_KEY_MATERIAL_FOUND':
      return l10n.errEncryptionKeyNotFound;

    // --- Audio ---------------------------------------------------------------
    case 'NOT_AN_AUDIO_FILE':
      return l10n.errNotAnAudioFile;
    case 'AUDIO_NOT_FOUND':
      return l10n.errAudioNotFound;
    case 'AUDIO_UPLOAD_FAILED':
      return l10n.errAudioUploadFailed;
    case 'AUDIO_DOWNLOAD_FAILED':
      return l10n.errAudioDownloadFailed;
    case 'AUDIO_DELETE_FAILED':
      return l10n.errAudioDeleteFailed;

    // --- Reminders -----------------------------------------------------------
    case 'REMINDER_NOT_FOUND':
      return l10n.errReminderNotFound;
    case 'REMINDER_CREATE_FAILED':
    case 'REMINDER_UPDATE_FAILED':
    case 'REMINDER_DELETE_FAILED':
    case 'REMINDER_FETCH_FAILED':
    case 'REMINDER_SYNC_FAILED':
      return l10n.errReminderOperationFailed;

    // --- Sync / usage --------------------------------------------------------
    case 'FOLDER_SYNC_FAILED':
      return l10n.errFolderSyncFailed;
    case 'USAGE_FETCH_FAILED':
    case 'USAGE_RECONCILE_FAILED':
    case 'USAGE_OCR_INCREMENT_FAILED':
    case 'USAGE_EXPORT_INCREMENT_FAILED':
      return l10n.errUsageOperationFailed;

    // Deliberately unmapped — these reach only admin/debug screens, which stay
    // in English, or are developer-facing bad-request diagnostics the user
    // cannot act on. They fall through to the server's English message.
    //   INVALID_ADMIN_CREDENTIALS, DEBUG_ONLY_ENDPOINT, JOB_*,
    //   INVALID_VERIFICATION_TOKEN, INVALID_FILENAME,
    //   INVALID_ENCRYPTION_MODE, ENCRYPTION_KEY_REQUIRED,
    //   MISSING_ZERO_KNOWLEDGE_FIELDS
    default:
      return null;
  }
}

/// Localized text for a failure that never reached the server, or that the
/// server answered without a code (network, timeout, 5xx, rate limit).
///
/// [ApiService] runs with no BuildContext, so it classifies the failure into an
/// [ApiErrorType] and stores English fallbacks; this turns that classification
/// into copy at the point of display. Same split as the sync layer: the service
/// produces something machine-readable, the UI renders it.
({String message, String? suggestion}) localizedTransportError(
  BuildContext context,
  ApiError error,
) {
  final l10n = AppL10n.of(context);
  switch (error.type) {
    case ApiErrorType.network:
      return (message: l10n.errCannotConnect, suggestion: l10n.errCheckConnection);
    case ApiErrorType.timeout:
      return (
        message: l10n.errNetworkTimeout,
        suggestion: l10n.errNetworkTimeoutHint,
      );
    case ApiErrorType.serverError:
      return (message: l10n.errServerProblem, suggestion: l10n.errTryAgainLater);
    case ApiErrorType.maintenance:
      return (
        message: l10n.errServerUnavailable,
        suggestion: l10n.errTryAgainMoment,
      );
    case ApiErrorType.rateLimit:
      return (message: l10n.errRateLimited, suggestion: l10n.errTryAgainMoment);
    case ApiErrorType.unauthorized:
      return (message: l10n.errSessionExpired, suggestion: null);
    case ApiErrorType.forbidden:
      return (message: l10n.errAccessDenied, suggestion: null);
    case ApiErrorType.notFound:
    case ApiErrorType.conflict:
    case ApiErrorType.unknown:
      // No better classification available; fall back to whatever the service
      // recorded, which for a coded error is the server's English message.
      return (message: error.userMessage, suggestion: error.suggestion);
  }
}
