const kNoteTypes = [
  'Title Content',
  'Record Audio',
  'Todo List',
  'Reminder',
];

// Map display names to database enum values
String getNoteTypeDbValue(String displayName) {
  switch (displayName) {
    case 'Title Content':
      return 'text';
    case 'Record Audio':
      return 'audio';
    case 'Todo List':
      return 'todo';
    case 'Reminder':
      return 'reminder';
    default:
      return 'text'; // Default fallback
  }
}

// Map database enum values to display names
String getNoteTypeDisplayName(String dbValue) {
  switch (dbValue) {
    case 'text':
      return 'Title Content';
    case 'audio':
      return 'Record Audio';
    case 'todo':
      return 'Todo List';
    case 'reminder':
      return 'Reminder';
    default:
      return 'Title Content'; // Default fallback
  }
}
