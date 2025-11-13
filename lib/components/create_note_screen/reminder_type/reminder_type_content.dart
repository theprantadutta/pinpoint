// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/notification_service.dart';

class ReminderTypeContent extends StatefulWidget {
  final TextEditingController descriptionController;
  final DateTime? selectedDateTime;
  final Function(DateTime selectedDateTime) onReminderDateTimeChanged;

  const ReminderTypeContent({
    super.key,
    required this.descriptionController,
    required this.selectedDateTime,
    required this.onReminderDateTimeChanged,
  });

  @override
  State<ReminderTypeContent> createState() => _ReminderTypeContentState();
}

class _ReminderTypeContentState extends State<ReminderTypeContent> {
  Future<void> _pickDateTime() async {
    // Check if exact alarm permission is needed (Android only)
    final prefs = await SharedPreferences.getInstance();
    final hasAskedExactAlarm =
        prefs.getBool('exact_alarm_permission_requested') ?? false;

    if (!hasAskedExactAlarm && mounted) {
      // Show explanation dialog for exact alarm permission
      final shouldRequest = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enable Precise Reminders'),
          content: const Text(
            'To ensure your reminders arrive exactly on time, '
            'we need permission to schedule precise alarms.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Enable'),
            ),
          ],
        ),
      );

      // Mark as asked regardless of user choice
      await prefs.setBool('exact_alarm_permission_requested', true);

      // Request permission if user agreed
      if (shouldRequest == true) {
        await NotificationService.requestScheduleExactAlarmPermission();
      }
    }

    // Continue with date/time picker
    DateTime now = DateTime.now();
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        widget.onReminderDateTimeChanged(DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Container(
          constraints: BoxConstraints(
            minHeight: MediaQuery.sizeOf(context).height * 0.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Description Field
              Text(
                "Description",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: widget.descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "What would you like to be reminded about?",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: cs.outline.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: cs.outline.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: cs.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // Reminder Time
              Text(
                "Reminder Time",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickDateTime,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primary.withValues(alpha: isDark ? 0.2 : 0.15),
                        cs.primary.withValues(alpha: isDark ? 0.1 : 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              cs.primary.withValues(alpha: isDark ? 0.3 : 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.calendar_today_rounded,
                          color: cs.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.selectedDateTime == null
                                  ? "Select Date & Time"
                                  : DateFormat("EEEE, d MMMM yyyy")
                                      .format(widget.selectedDateTime!),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            if (widget.selectedDateTime != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                DateFormat("h:mm a")
                                    .format(widget.selectedDateTime!),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: cs.onSurface.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Info Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark
                      ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cs.outline.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Reminder Details',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      '• A notification will be sent at the selected time',
                      cs,
                    ),
                    const SizedBox(height: 6),
                    _buildInfoItem(
                      '• Ensure notifications are enabled in settings',
                      cs,
                    ),
                    const SizedBox(height: 6),
                    _buildInfoItem(
                      '• You can edit or delete this reminder anytime',
                      cs,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text, ColorScheme cs) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.5,
        color: cs.onSurface.withValues(alpha: 0.7),
      ),
    );
  }
}
