// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/notification_service.dart';
import 'package:pinpoint/util/localized_dates.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

class ReminderTypeContent extends StatefulWidget {
  final TextEditingController notificationTitleController;
  final TextEditingController notificationContentController;
  final DateTime? selectedDateTime;
  final String recurrenceType;
  final int recurrenceInterval;
  final String recurrenceEndType;
  final String? recurrenceEndValue;
  final Function(DateTime selectedDateTime) onReminderDateTimeChanged;
  final Function(String type) onRecurrenceTypeChanged;
  final Function(int interval) onRecurrenceIntervalChanged;
  final Function(String type) onRecurrenceEndTypeChanged;
  final Function(String? value) onRecurrenceEndValueChanged;

  const ReminderTypeContent({
    super.key,
    required this.notificationTitleController,
    required this.notificationContentController,
    required this.selectedDateTime,
    required this.recurrenceType,
    required this.recurrenceInterval,
    required this.recurrenceEndType,
    this.recurrenceEndValue,
    required this.onReminderDateTimeChanged,
    required this.onRecurrenceTypeChanged,
    required this.onRecurrenceIntervalChanged,
    required this.onRecurrenceEndTypeChanged,
    required this.onRecurrenceEndValueChanged,
  });

  @override
  State<ReminderTypeContent> createState() => _ReminderTypeContentState();
}

class _ReminderTypeContentState extends State<ReminderTypeContent> {
  final TextEditingController _endOccurrencesController = TextEditingController();
  DateTime? _endDate;
  List<DateTime> _previewOccurrences = [];

  @override
  void initState() {
    super.initState();
    if (widget.recurrenceEndType == 'after_occurrences' && widget.recurrenceEndValue != null) {
      _endOccurrencesController.text = widget.recurrenceEndValue!;
    } else if (widget.recurrenceEndType == 'on_date' && widget.recurrenceEndValue != null) {
      try {
        _endDate = DateTime.parse(widget.recurrenceEndValue!);
      } catch (e) {
        // Invalid date
      }
    }
    _updatePreview();
  }

  @override
  void didUpdateWidget(ReminderTypeContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDateTime != widget.selectedDateTime ||
        oldWidget.recurrenceType != widget.recurrenceType ||
        oldWidget.recurrenceInterval != widget.recurrenceInterval ||
        oldWidget.recurrenceEndType != widget.recurrenceEndType ||
        oldWidget.recurrenceEndValue != widget.recurrenceEndValue) {
      _updatePreview();
    }
  }

  void _updatePreview() {
    if (widget.selectedDateTime == null) {
      setState(() {
        _previewOccurrences = [];
      });
      return;
    }

    setState(() {
      _previewOccurrences = _generateOccurrenceTimes(
        startTime: widget.selectedDateTime!,
        recurrenceType: widget.recurrenceType,
        recurrenceInterval: widget.recurrenceInterval,
        recurrenceEndType: widget.recurrenceEndType,
        recurrenceEndValue: widget.recurrenceEndValue,
        maxOccurrences: 5, // Preview first 5
      );
    });
  }

  List<DateTime> _generateOccurrenceTimes({
    required DateTime startTime,
    required String recurrenceType,
    required int recurrenceInterval,
    required String recurrenceEndType,
    String? recurrenceEndValue,
    int maxOccurrences = 5,
  }) {
    if (recurrenceType == 'once') {
      return [startTime];
    }

    final occurrences = <DateTime>[startTime];
    DateTime currentTime = startTime;

    int maxCount = maxOccurrences;
    DateTime? endDate;

    if (recurrenceEndType == 'after_occurrences' && recurrenceEndValue != null) {
      try {
        maxCount = int.parse(recurrenceEndValue);
        if (maxCount > maxOccurrences) maxCount = maxOccurrences;
      } catch (e) {
        // Invalid number
      }
    } else if (recurrenceEndType == 'on_date' && recurrenceEndValue != null) {
      try {
        endDate = DateTime.parse(recurrenceEndValue);
      } catch (e) {
        // Invalid date
      }
    }

    while (occurrences.length < maxCount) {
      switch (recurrenceType) {
        case 'hourly':
          currentTime = currentTime.add(Duration(hours: recurrenceInterval));
          break;
        case 'daily':
          currentTime = currentTime.add(Duration(days: recurrenceInterval));
          break;
        case 'weekly':
          currentTime = currentTime.add(Duration(days: 7 * recurrenceInterval));
          break;
        case 'monthly':
          currentTime = DateTime(
            currentTime.year,
            currentTime.month + recurrenceInterval,
            currentTime.day,
            currentTime.hour,
            currentTime.minute,
          );
          break;
        case 'yearly':
          currentTime = DateTime(
            currentTime.year + recurrenceInterval,
            currentTime.month,
            currentTime.day,
            currentTime.hour,
            currentTime.minute,
          );
          break;
        default:
          return occurrences;
      }

      if (endDate != null && currentTime.isAfter(endDate)) {
        break;
      }

      occurrences.add(currentTime);
    }

    return occurrences;
  }

  Future<void> _pickDateTime() async {
    // Check if exact alarm permission is needed (Android only)
    final prefs = await SharedPreferences.getInstance();
    final hasAskedExactAlarm = prefs.getBool('exact_alarm_permission_requested') ?? false;

    if (!hasAskedExactAlarm && mounted) {
      // Show explanation dialog for exact alarm permission
      final shouldRequest = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppL10n.of(context).remPreciseTitle),
          content: Text(AppL10n.of(context).remPreciseBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppL10n.of(context).remSkip),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(AppL10n.of(context).remEnable),
            ),
          ],
        ),
      );

      await prefs.setBool('exact_alarm_permission_requested', true);

      if (shouldRequest == true) {
        await NotificationService.requestScheduleExactAlarmPermission();
      }
    }

    // Continue with date/time picker - ONLY FUTURE DATES
    DateTime now = DateTime.now();
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now, // Can only pick today or future
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        final selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        // Validate it's in the future
        if (selectedDateTime.isAfter(DateTime.now())) {
          widget.onReminderDateTimeChanged(selectedDateTime);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppL10n.of(context).remMustBeFuture),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _pickEndDate() async {
    DateTime now = DateTime.now();
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now,
      firstDate: now,
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        _endDate = pickedDate;
      });
      widget.onRecurrenceEndValueChanged(pickedDate.toIso8601String());
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
              // Notification Title Field
              Text(
                "Notification Title",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: widget.notificationTitleController,
                maxLines: 1,
                decoration: InputDecoration(
                  hintText: "e.g., Take medication",
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
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 20),

              // Notification Content Field
              Text(
                "Notification Content (Optional)",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: widget.notificationContentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Additional details about the reminder...",
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
                style: const TextStyle(
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
                          color: cs.primary.withValues(alpha: isDark ? 0.3 : 0.2),
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
                                  : LocalizedDates.fullDate(context, widget.selectedDateTime!),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            if (widget.selectedDateTime != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                LocalizedDates.time(context, widget.selectedDateTime!),
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

              const SizedBox(height: 24),

              // Recurrence Section
              Text(
                "Recurrence",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),

              // Recurrence Type Dropdown
              DropdownButtonFormField<String>(
                initialValue: widget.recurrenceType,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.repeat_rounded),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: [
                  DropdownMenuItem(value: 'once', child: Text(AppL10n.of(context).remOnce)),
                  DropdownMenuItem(value: 'hourly', child: Text(AppL10n.of(context).remHourly)),
                  DropdownMenuItem(value: 'daily', child: Text(AppL10n.of(context).remDaily)),
                  DropdownMenuItem(value: 'weekly', child: Text(AppL10n.of(context).remWeekly)),
                  DropdownMenuItem(value: 'monthly', child: Text(AppL10n.of(context).remMonthly)),
                  DropdownMenuItem(value: 'yearly', child: Text(AppL10n.of(context).remYearly)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    widget.onRecurrenceTypeChanged(value);
                  }
                },
              ),

              // Interval Input (only show if not 'once')
              if (widget.recurrenceType != 'once') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: AppL10n.of(context).remEvery,
                          suffixText: _getIntervalUnit(widget.recurrenceType),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        ),
                        controller: TextEditingController(text: widget.recurrenceInterval.toString())
                          ..selection = TextSelection.fromPosition(
                            TextPosition(offset: widget.recurrenceInterval.toString().length),
                          ),
                        onChanged: (value) {
                          final interval = int.tryParse(value) ?? 1;
                          if (interval > 0 && interval <= 100) {
                            widget.onRecurrenceIntervalChanged(interval);
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // End Condition
                Text(
                  "End Condition",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: widget.recurrenceEndType,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.event_repeat_rounded),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: [
                    DropdownMenuItem(value: 'never', child: Text(AppL10n.of(context).remNeverEnds)),
                    DropdownMenuItem(value: 'after_occurrences', child: Text(AppL10n.of(context).remAfterOccurrences)),
                    DropdownMenuItem(value: 'on_date', child: Text(AppL10n.of(context).remOnDate)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      widget.onRecurrenceEndTypeChanged(value);
                      if (value == 'never') {
                        widget.onRecurrenceEndValueChanged(null);
                      }
                    }
                  },
                ),

                // End value input
                if (widget.recurrenceEndType == 'after_occurrences') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _endOccurrencesController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: AppL10n.of(context).remOccurrenceCount,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                    onChanged: (value) {
                      widget.onRecurrenceEndValueChanged(value.isEmpty ? null : value);
                    },
                  ),
                ] else if (widget.recurrenceEndType == 'on_date') ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickEndDate,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(16),
                        color: isDark
                            ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: cs.primary),
                          const SizedBox(width: 12),
                          Text(
                            _endDate == null
                                ? AppL10n.of(context).remSelectEndDate
                                : LocalizedDates.fullDate(context, _endDate!),
                            style: TextStyle(fontSize: 15, color: cs.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Preview of Occurrences
                if (_previewOccurrences.isNotEmpty && widget.selectedDateTime != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.preview_rounded, size: 20, color: cs.primary),
                            const SizedBox(width: 8),
                            Text(
                              AppL10n.of(context).remPreview(_previewOccurrences.length),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._previewOccurrences.asMap().entries.map((entry) {
                          final index = entry.key;
                          final occurrence = entry.value;
                          return Padding(
                            padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: cs.primary.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: cs.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  LocalizedDates.dateTime(context, occurrence),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: cs.onSurface.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],

              const SizedBox(height: 16),

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
                          AppL10n.of(context).remDetails,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem('• Notification title and content will appear in push notifications', cs),
                    const SizedBox(height: 6),
                    _buildInfoItem('• Ensure notifications are enabled in settings', cs),
                    const SizedBox(height: 6),
                    _buildInfoItem('• Recurring reminders create multiple scheduled notifications', cs),
                    const SizedBox(height: 6),
                    _buildInfoItem('• You can edit or delete reminders anytime', cs),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getIntervalUnit(String recurrenceType) {
    switch (recurrenceType) {
      case 'hourly':
        return 'hour(s)';
      case 'daily':
        return 'day(s)';
      case 'weekly':
        return 'week(s)';
      case 'monthly':
        return 'month(s)';
      case 'yearly':
        return 'year(s)';
      default:
        return '';
    }
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

  @override
  void dispose() {
    _endOccurrencesController.dispose();
    super.dispose();
  }
}
