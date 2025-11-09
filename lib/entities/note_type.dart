/// Enum representing the type of a note
/// Each note can only have ONE type (single responsibility principle)
enum NoteType {
  text('text'),
  audio('audio'),
  todo('todo'),
  reminder('reminder');

  final String value;
  const NoteType(this.value);

  /// Convert a string to a NoteType enum
  static NoteType fromString(String value) {
    return NoteType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NoteType.text, // Default to text if unknown
    );
  }

  /// Convert enum to string for database storage
  @override
  String toString() => value;
}
