import 'package:drift/drift.dart';

class NoteFolders extends Table {
  IntColumn get noteFolderId => integer().autoIncrement()();

  /// Globally unique identifier for sync
  TextColumn get uuid => text().unique()();

  TextColumn get noteFolderTitle => text().unique()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
