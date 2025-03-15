import 'package:drift/drift.dart';

class NoteFolders extends Table {
  IntColumn get noteFolderId => integer().autoIncrement()();
  TextColumn get noteFolderTitle => text().unique()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
