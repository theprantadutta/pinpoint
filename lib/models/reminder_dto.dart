/// Data Transfer Object for Reminder API communication
class ReminderDto {
  final String? id; // UUID from backend (null for create)
  final String noteUuid; // Client-side note UUID
  final String title; // Note title (for app organization)
  final String notificationTitle; // Title shown in push notification
  final String? notificationContent; // Content shown in notification body
  final String? description; // Deprecated, for backward compatibility
  final DateTime reminderTime;

  // Recurrence fields
  final String recurrenceType; // once, hourly, daily, weekly, monthly, yearly
  final int recurrenceInterval; // Every X hours/days/weeks
  final String recurrenceEndType; // never, after_occurrences, on_date
  final String? recurrenceEndValue; // Number or ISO date string
  final String? parentReminderId; // Link to parent reminder
  final int occurrenceNumber; // Which occurrence (1, 2, 3...)
  final String? seriesId; // UUID to group all occurrences

  final bool? isTriggered; // Only from backend responses
  final DateTime? triggeredAt; // Only from backend responses
  final DateTime? createdAt; // Only from backend responses
  final DateTime? updatedAt; // Only from backend responses

  ReminderDto({
    this.id,
    required this.noteUuid,
    required this.title,
    required this.notificationTitle,
    this.notificationContent,
    this.description,
    required this.reminderTime,
    this.recurrenceType = 'once',
    this.recurrenceInterval = 1,
    this.recurrenceEndType = 'never',
    this.recurrenceEndValue,
    this.parentReminderId,
    this.occurrenceNumber = 1,
    this.seriesId,
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
      'notification_title': notificationTitle,
      'notification_content': notificationContent,
      'reminder_time': reminderTime.toUtc().toIso8601String(),
      'recurrence_type': recurrenceType,
      'recurrence_interval': recurrenceInterval,
      'recurrence_end_type': recurrenceEndType,
      if (recurrenceEndValue != null) 'recurrence_end_value': recurrenceEndValue,
    };
  }

  /// Convert to JSON for API request (update)
  Map<String, dynamic> toJsonUpdate() {
    return {
      if (title.isNotEmpty) 'title': title,
      if (notificationTitle.isNotEmpty) 'notification_title': notificationTitle,
      'notification_content': notificationContent,
      'reminder_time': reminderTime.toUtc().toIso8601String(),
      'recurrence_type': recurrenceType,
      'recurrence_interval': recurrenceInterval,
      'recurrence_end_type': recurrenceEndType,
      if (recurrenceEndValue != null) 'recurrence_end_value': recurrenceEndValue,
    };
  }

  /// Convert to JSON for sync request
  Map<String, dynamic> toJsonSync() {
    return {
      'note_uuid': noteUuid,
      'title': title,
      'notification_title': notificationTitle,
      'notification_content': notificationContent,
      'description': description, // For backward compatibility
      'reminder_time': reminderTime.toUtc().toIso8601String(),
      'recurrence_type': recurrenceType,
      'recurrence_interval': recurrenceInterval,
      'recurrence_end_type': recurrenceEndType,
      if (recurrenceEndValue != null) 'recurrence_end_value': recurrenceEndValue,
      if (parentReminderId != null) 'parent_reminder_id': parentReminderId,
      'occurrence_number': occurrenceNumber,
      if (seriesId != null) 'series_id': seriesId,
    };
  }

  /// Create from API response JSON
  factory ReminderDto.fromJson(Map<String, dynamic> json) {
    return ReminderDto(
      id: json['id'] as String?,
      noteUuid: json['note_uuid'] as String,
      title: json['title'] as String,
      notificationTitle: json['notification_title'] as String? ?? json['title'] as String,
      notificationContent: json['notification_content'] as String?,
      description: json['description'] as String?,
      reminderTime: DateTime.parse(json['reminder_time'] as String).toLocal(),
      recurrenceType: json['recurrence_type'] as String? ?? 'once',
      recurrenceInterval: json['recurrence_interval'] as int? ?? 1,
      recurrenceEndType: json['recurrence_end_type'] as String? ?? 'never',
      recurrenceEndValue: json['recurrence_end_value'] as String?,
      parentReminderId: json['parent_reminder_id'] as String?,
      occurrenceNumber: json['occurrence_number'] as int? ?? 1,
      seriesId: json['series_id'] as String?,
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

  /// Create from local reminder note data
  factory ReminderDto.fromLocal({
    required String noteUuid,
    required String title,
    required String notificationTitle,
    String? notificationContent,
    String? description,
    required DateTime reminderTime,
    String recurrenceType = 'once',
    int recurrenceInterval = 1,
    String recurrenceEndType = 'never',
    String? recurrenceEndValue,
    String? parentReminderId,
    int occurrenceNumber = 1,
    String? seriesId,
  }) {
    return ReminderDto(
      noteUuid: noteUuid,
      title: title,
      notificationTitle: notificationTitle,
      notificationContent: notificationContent,
      description: description,
      reminderTime: reminderTime,
      recurrenceType: recurrenceType,
      recurrenceInterval: recurrenceInterval,
      recurrenceEndType: recurrenceEndType,
      recurrenceEndValue: recurrenceEndValue,
      parentReminderId: parentReminderId,
      occurrenceNumber: occurrenceNumber,
      seriesId: seriesId,
    );
  }

  @override
  String toString() {
    return 'ReminderDto(id: $id, noteUuid: $noteUuid, title: $title, notificationTitle: $notificationTitle, reminderTime: $reminderTime, recurrence: $recurrenceType, occurrence: $occurrenceNumber)';
  }
}
