/// Data Transfer Object for Reminder API communication
class ReminderDto {
  final String? id; // UUID from backend (null for create)
  final String noteUuid; // Client-side note UUID
  final String title;
  final String? description;
  final DateTime reminderTime;
  final bool? isTriggered; // Only from backend responses
  final DateTime? triggeredAt; // Only from backend responses
  final DateTime? createdAt; // Only from backend responses
  final DateTime? updatedAt; // Only from backend responses

  ReminderDto({
    this.id,
    required this.noteUuid,
    required this.title,
    this.description,
    required this.reminderTime,
    this.isTriggered,
    this.triggeredAt,
    this.createdAt,
    this.updatedAt,
  });

  /// Convert to JSON for API request (create)
  Map<String, dynamic> toJsonCreate() {
    return {
      'note_uuid': noteUuid,
      'title': title,
      'description': description,
      'reminder_time': reminderTime.toUtc().toIso8601String(),
    };
  }

  /// Convert to JSON for API request (update)
  Map<String, dynamic> toJsonUpdate() {
    return {
      if (title.isNotEmpty) 'title': title,
      'description': description,
      'reminder_time': reminderTime.toUtc().toIso8601String(),
    };
  }

  /// Convert to JSON for sync request
  Map<String, dynamic> toJsonSync() {
    return {
      'note_uuid': noteUuid,
      'title': title,
      'description': description,
      'reminder_time': reminderTime.toUtc().toIso8601String(),
    };
  }

  /// Create from API response JSON
  factory ReminderDto.fromJson(Map<String, dynamic> json) {
    return ReminderDto(
      id: json['id'] as String?,
      noteUuid: json['note_uuid'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      reminderTime: DateTime.parse(json['reminder_time'] as String).toLocal(),
      isTriggered: json['is_triggered'] as bool?,
      triggeredAt: json['triggered_at'] != null
          ? DateTime.parse(json['triggered_at'] as String).toLocal()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String).toLocal()
          : null,
    );
  }

  /// Create from local reminder note data (for migration)
  factory ReminderDto.fromLocal({
    required String noteUuid,
    required String title,
    String? description,
    required DateTime reminderTime,
  }) {
    return ReminderDto(
      noteUuid: noteUuid,
      title: title,
      description: description,
      reminderTime: reminderTime,
    );
  }

  @override
  String toString() {
    return 'ReminderDto(id: $id, noteUuid: $noteUuid, title: $title, reminderTime: $reminderTime)';
  }
}
