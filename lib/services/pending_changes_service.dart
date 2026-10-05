import 'package:drift/drift.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';

/// How many local notes have changes that have not been uploaded yet.
///
/// A local query only — it never touches the network, so the Settings card
/// and the Sync screen can show "3 changes waiting" offline. Deleted notes
/// count too: a deletion is a change the server has not heard about.
class PendingChangesService {
  PendingChangesService._();

  /// Emits the count now and again whenever the notes table changes.
  static Stream<int> watchCount() {
    if (!getIt.isRegistered<AppDatabase>()) return Stream.value(0);
    final db = getIt<AppDatabase>();
    final count = db.notes.id.count();
    final query = db.selectOnly(db.notes)
      ..addColumns([count])
      ..where(db.notes.isSynced.equals(false));
    return query
        .map((row) => row.read(count) ?? 0)
        .watchSingle()
        .handleError((_) {});
  }
}
