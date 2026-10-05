import 'package:drift/drift.dart';

class NoteFolders extends Table {
  IntColumn get noteFolderId => integer().autoIncrement()();

  /// Globally unique identifier for sync
  TextColumn get uuid => text().unique()();

  TextColumn get noteFolderTitle => text().unique()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Sketchbook pastel name: yellow | lavender | mint | sky | pink.
  ///
  /// Null on folders created before schema v12 (and by older clients). A null
  /// colour is resolved at display time, round-robin in creation order, so
  /// every device shows the same colour without a write — see FolderPalette.
  TextColumn get color => text().nullable()();

  /// Manual order from the My folders reorder mode. Null sorts after any
  /// ordered folder, by creation.
  IntColumn get sortOrder => integer().nullable()();
}
