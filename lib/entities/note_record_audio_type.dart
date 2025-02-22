import 'package:drift/drift.dart';

import 'note.dart';

class NoteRecordAudioTypes extends Table {
  IntColumn get id => integer().references(Notes, #id)(); // FK to Notes.id
  TextColumn get filePath => text()();
  IntColumn get duration => integer()();
}
