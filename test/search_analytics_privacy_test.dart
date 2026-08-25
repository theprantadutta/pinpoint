import 'package:flutter_test/flutter_test.dart';

import 'package:pinpoint/services/analytics/analytics_client.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/services/analytics/logger_analytics_client.dart';

import 'support/analytics_recorder.dart';
import 'support/project_source.dart';

/// Search terms are note content, and Pinpoint is end-to-end encrypted: the
/// server never sees a title, a body or a checklist item. Shipping the search
/// box's text to Firebase re-opened exactly the channel the encryption exists
/// to close — `firebase_analytics_client.dart` used to log `{'query': query}`
/// verbatim, on a 280 ms debounce, so a single typed word left a trail of its
/// own prefixes in someone else's datastore.
///
/// What may leave the device is a coarse length bucket and nothing else.
void main() {
  // Real search terms, in the scripts the app ships. None of these — nor any
  // fragment of them — may appear in an analytics payload.
  const bengali = 'আমার গোপন নোট';
  const arabic = 'كلمة السر';
  const persian = 'رمز عبور من';
  const thai = 'รหัสผ่านของฉัน';
  const latin = 'bank password';

  group('bucket boundaries', () {
    test('the four buckets divide exactly where they claim to', () {
      expect(searchLengthBucket(1), '1-3');
      expect(searchLengthBucket(2), '1-3');
      expect(searchLengthBucket(3), '1-3');

      expect(searchLengthBucket(4), '4-10');
      expect(searchLengthBucket(9), '4-10');
      expect(searchLengthBucket(10), '4-10');

      expect(searchLengthBucket(11), '11-25');
      expect(searchLengthBucket(24), '11-25');
      expect(searchLengthBucket(25), '11-25');

      expect(searchLengthBucket(26), '26+');
      expect(searchLengthBucket(500), '26+');
    });

    test('every bucket is one of the four documented values', () {
      const allowed = {'1-3', '4-10', '11-25', '26+'};
      for (var length = 0; length <= 200; length++) {
        expect(allowed, contains(searchLengthBucket(length)));
      }
    });

    test('the bucket is monotonic — it can only widen with length', () {
      const order = ['1-3', '4-10', '11-25', '26+'];
      var previous = 0;
      for (var length = 1; length <= 200; length++) {
        final index = order.indexOf(searchLengthBucket(length));
        expect(index, greaterThanOrEqualTo(previous));
        previous = index;
      }
    });
  });

  group('non-Latin queries', () {
    test('length is counted in characters, not bytes', () {
      // The naive alternative — UTF-8 byte length — would put every one of
      // these in a wildly wrong bucket: Bengali and Thai are 3 bytes per
      // character, Arabic and Persian 2.
      expect(bengali.runes.length, 13);
      expect(searchLengthBucket(bengali.runes.length), '11-25');

      expect(arabic.runes.length, 9);
      expect(searchLengthBucket(arabic.runes.length), '4-10');

      expect(persian.runes.length, 11);
      expect(searchLengthBucket(persian.runes.length), '11-25');

      expect(thai.runes.length, 14);
      expect(searchLengthBucket(thai.runes.length), '11-25');
    });

    test('runes and UTF-16 code units bucket differently — runes are right',
        () {
      // Bengali, Arabic, Persian and Thai all live in the BMP, so for them the
      // two counts agree. Astral-plane characters are where a `.length` would
      // silently inflate the bucket: two characters counted as four.
      const astral = '𝟏𝟐'; // two mathematical digits, one surrogate pair each
      expect(astral.runes.length, 2);
      expect(astral.length, 4, reason: 'UTF-16 code units, not characters.');

      expect(searchLengthBucket(astral.runes.length), '1-3');
      expect(
        searchLengthBucket(astral.length),
        '4-10',
        reason: 'This is the wrong answer the rune count avoids.',
      );
    });

    test('the search screen counts runes, not UTF-16 code units', () {
      // The rune count itself lives in the screen, which is why this is a
      // source guard rather than a behavioural assertion.
      final source = readProjectFile('lib/screens/notes_screen.dart');
      expect(
        source,
        contains('query.trim().runes.length'),
        reason: 'notes_screen must count characters. `query.length` counts '
            'UTF-16 code units and mis-buckets astral-plane scripts.',
      );
      expect(
        RegExp(r'trackSearchPerformed\(\s*queryLength:').hasMatch(source),
        isTrue,
      );
      expect(
        RegExp(r'trackSearchPerformed\([^)]*query:').hasMatch(source),
        isFalse,
        reason: 'The query text itself must never be passed.',
      );
    });
  });

  group('what actually goes on the wire', () {
    late LoggerCapture capture;

    setUp(() {
      capture = LoggerCapture()..start();
    });

    tearDown(() => capture.stop());

    test('search_performed carries a bucket and nothing else', () async {
      await LoggerAnalyticsClient().trackSearchPerformed(queryLength: 7);

      final event = capture.one('search_performed');
      expect(event.params.keys, ['query_length_bucket']);
      expect(event.params['query_length_bucket'], '4-10');
    });

    test('no fragment of a real query survives the full facade chain',
        () async {
      // The production path end to end: facade -> logger client -> wire.
      final facade = AnalyticsFacade(logger: LoggerAnalyticsClient());

      for (final query in [bengali, arabic, persian, thai, latin]) {
        await facade.trackSearchPerformed(queryLength: query.runes.length);
      }

      expect(capture.events, hasLength(5));
      for (final event in capture.events) {
        for (final query in [bengali, arabic, persian, thai, latin]) {
          // The whole query must not appear anywhere in the emitted line...
          final line = '${event.name} ${event.params}';
          expect(line, isNot(contains(query)));

          // ...and no fragment of it may appear in a parameter VALUE, which is
          // where a truncated or "anonymised" query would end up. (The event
          // NAME is excluded on purpose: "search_perf-or-med" contains "or".)
          final runes = query.runes.toList();
          for (final value in event.params.values) {
            for (var i = 0; i + 3 <= runes.length; i++) {
              final fragment = String.fromCharCodes(runes.sublist(i, i + 3));
              if (fragment.trim().length < 3) continue;
              expect(
                value,
                isNot(contains(fragment)),
                reason: 'Fragment "$fragment" of "$query" leaked into "$value"',
              );
            }
          }
        }
      }
    });

    test('no captured parameter value equals or contains the query text',
        () async {
      final recorder = RecordingAnalyticsFacade();
      for (final query in [bengali, arabic, persian, thai, latin]) {
        await recorder.trackSearchPerformed(queryLength: query.runes.length);
      }

      expect(recorder.allParameterValues, isNotEmpty);
      for (final value in recorder.allParameterValues) {
        for (final query in [bengali, arabic, persian, thai, latin]) {
          expect(value, isNot(equals(query)));
          expect(value, isNot(contains(query)));
        }
        expect(
          const {'1-3', '4-10', '11-25', '26+'},
          contains(value),
          reason: 'search_performed emitted a value that is not a bucket.',
        );
      }
    });
  });

  group('source guards', () {
    test('no analytics file names a search query parameter', () {
      for (final path in const [
        'lib/services/analytics/analytics_client.dart',
        'lib/services/analytics/analytics_facade.dart',
        'lib/services/analytics/firebase_analytics_client.dart',
        'lib/services/analytics/logger_analytics_client.dart',
      ]) {
        final source = readProjectFile(path);
        expect(
          source.contains("'query': "),
          isFalse,
          reason: '$path is shipping the raw search text again.',
        );
        expect(
          RegExp(r'trackSearchPerformed\(\{[^}]*String query').hasMatch(source),
          isFalse,
          reason: '$path takes the query text instead of its length. Not raw, '
              'not truncated, not hashed — a hash of a short query is '
              'trivially reversible and is still content-derived.',
        );
        expect(
          RegExp(r'trackSearchPerformed\(\{[^}]*int queryLength')
              .hasMatch(source),
          isTrue,
        );
      }
    });

    test('the bucket boundaries live in exactly one place', () {
      final client =
          readProjectFile('lib/services/analytics/analytics_client.dart');
      expect(client, contains('String searchLengthBucket(int queryLength)'));

      // Each leaf client must call the shared helper rather than re-deriving
      // boundaries that would then drift apart.
      for (final path in const [
        'lib/services/analytics/firebase_analytics_client.dart',
        'lib/services/analytics/logger_analytics_client.dart',
      ]) {
        expect(readProjectFile(path), contains('searchLengthBucket('));
      }
    });

    test('nothing else in lib/ passes text to trackSearchPerformed', () {
      final offenders = <String>[];
      for (final entry in dartFilesUnder('lib')) {
        for (final match
            in RegExp(r'trackSearchPerformed\(([^)]*)\)').allMatches(entry.value)) {
          final args = match.group(1)!;
          // Matches declarations (`{required int queryLength}`) as well as
          // call sites (`queryLength: n`); both are fine, anything else is not.
          if (!args.contains('queryLength')) {
            offenders.add('${entry.key}: $args');
          }
        }
      }
      expect(offenders, isEmpty);
    });
  });
}
