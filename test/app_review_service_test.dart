import 'package:flutter_test/flutter_test.dart';

import 'support/project_source.dart';

/// Review 2026-11-01, F11: "Rate Pinpoint" on iOS opens the App Store listing,
/// which needs the app's id; it was an empty string.
void main() {
  test('the App Store id is set', () {
    expect(readProjectFile('lib/services/app_review_service.dart'),
        contains("_appStoreId = '6786222392'"));
  });
}
