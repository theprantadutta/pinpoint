import 'dart:convert';

import 'package:flutter/foundation.dart';

/// OCR scans and exports the server has not been told about yet, because the
/// device was offline or the server was down when they happened.
///
/// Each record belongs to one account and one quota month: it is replayed
/// only to the account that used it, and only within the month it counts
/// toward. Anything else is stale and dropped. Guests have no server
/// counter, so nothing is queued for them.
///
/// These quotas are client-side UX, not tamper-proof metering — OCR and
/// export run on the device, and a modified client can skip the count
/// entirely. The goal is that honest offline use is neither lost nor
/// counted twice.
@immutable
class PendingUsage {
  const PendingUsage({
    required this.owner,
    required this.period,
    this.ocr = 0,
    this.exports = 0,
  });

  static const String prefsKey = 'usage_pending';

  /// Account id the usage belongs to.
  final String owner;

  /// Quota month, as `PremiumService.quotaPeriodOf` writes it ("2026-10").
  final String period;
  final int ocr;
  final int exports;

  bool get isEmpty => ocr <= 0 && exports <= 0;

  /// Whether this record still applies to [owner] in [period].
  bool appliesTo(String? owner, String period) =>
      owner != null && owner == this.owner && period == this.period;

  /// The record to keep for [owner] in [period]: this one if it applies,
  /// otherwise a fresh, empty one.
  PendingUsage forScope(String owner, String period) =>
      appliesTo(owner, period) ? this : PendingUsage(owner: owner, period: period);

  PendingUsage copyWith({int? ocr, int? exports}) => PendingUsage(
        owner: owner,
        period: period,
        ocr: ocr ?? this.ocr,
        exports: exports ?? this.exports,
      );

  /// What to show locally: the server's count plus what it has not heard of.
  static int merge(int serverCount, int pending) =>
      serverCount + (pending > 0 ? pending : 0);

  String encode() => jsonEncode(
      {'owner': owner, 'period': period, 'ocr': ocr, 'exports': exports});

  static PendingUsage? decode(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return PendingUsage(
        owner: m['owner'] as String,
        period: m['period'] as String,
        ocr: (m['ocr'] as num?)?.toInt() ?? 0,
        exports: (m['exports'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}
