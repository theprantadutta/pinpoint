// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../design_system/design_system.dart';
import '../../../services/notification_service.dart';
import '../../../util/show_a_toast.dart';
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
  final TextEditingController _endOccurrencesController =
      TextEditingController();
  DateTime? _endDate;
  List<DateTime> _previewOccurrences = [];

  @override
  void initState() {
    super.initState();
    if (widget.recurrenceEndType == 'after_occurrences' &&
        widget.recurrenceEndValue != null) {
      _endOccurrencesController.text = widget.recurrenceEndValue!;
    } else if (widget.recurrenceEndType == 'on_date' &&
        widget.recurrenceEndValue != null) {
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

    if (recurrenceEndType == 'after_occurrences' &&
        recurrenceEndValue != null) {
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
    final hasAskedExactAlarm =
        prefs.getBool('exact_alarm_permission_requested') ?? false;

    if (!hasAskedExactAlarm && mounted) {
      // Explain the exact alarm permission before the system screen.
      final shouldRequest = await showSketchSheet<bool>(
        context: context,
        builder: (ctx) {
          final l10n = AppL10n.of(ctx);
          return SketchSheet(
            title: l10n.remPreciseTitle,
            scrollable: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.remPreciseBody,
                    style: ctx.type.bodyRegular
                        .copyWith(fontSize: 14, color: ctx.sketch.muted)),
                const SizedBox(height: 20),
                PillButton(
                  label: l10n.remEnable,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
                const SizedBox(height: 10),
                PillButton.secondary(
                  label: l10n.remSkip,
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
              ],
            ),
          );
        },
      );

      await prefs.setBool('exact_alarm_permission_requested', true);

      if (shouldRequest == true) {
        await NotificationService.requestScheduleExactAlarmPermission();
      }
    }

    if (!mounted) return;

    // Continue with date/time picker - ONLY FUTURE DATES
    DateTime now = DateTime.now();
    final current = widget.selectedDateTime;
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: current != null && current.isAfter(now) ? current : now,
      firstDate: now, // Can only pick today or future
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && mounted) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime:
            current != null ? TimeOfDay.fromDateTime(current) : TimeOfDay.now(),
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
        } else if (mounted) {
          showSketchToast(
            context: context,
            message: AppL10n.of(context).remMustBeFuture,
            tone: ToastTone.warning,
          );
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

  String _intervalLabel(AppL10n l10n, int n) => switch (widget.recurrenceType) {
        'hourly' => l10n.edRemEveryHours(n),
        'daily' => l10n.edRemEveryDays(n),
        'weekly' => l10n.edRemEveryWeeks(n),
        'monthly' => l10n.edRemEveryMonths(n),
        'yearly' => l10n.edRemEveryYears(n),
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;
    final t = context.type;
    final when = widget.selectedDateTime;

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: SketchSpace.section, bottom: 10),
          child: Semantics(header: true, child: Text(text, style: t.body)),
        );

    final repeatOptions = <(String, String)>[
      ('once', l10n.remOnce),
      ('hourly', l10n.remHourly),
      ('daily', l10n.remDaily),
      ('weekly', l10n.remWeekly),
      ('monthly', l10n.remMonthly),
      ('yearly', l10n.remYearly),
    ];
    final endOptions = <(String, String)>[
      ('never', l10n.remNeverEnds),
      ('after_occurrences', l10n.remAfterOccurrences),
      ('on_date', l10n.remOnDate),
    ];

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            SketchSpace.editorX, 4, SketchSpace.editorX, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // When
            label(l10n.edRemWhen),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 2,
              children: [
                ReminderChip(when: when, onTap: _pickDateTime),
                if (when != null)
                  Text(LocalizedDates.fullDate(context, when),
                      style: t.bodySmall.copyWith(color: s.muted)),
              ],
            ),

            // Notification title
            label(l10n.edRemTitleLabel),
            TextField(
              controller: widget.notificationTitleController,
              maxLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: l10n.edRemTitleHint),
              style: t.bodyRegular.copyWith(color: s.ink),
            ),

            // Notification content
            label(l10n.edRemBodyLabel),
            TextField(
              controller: widget.notificationContentController,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: l10n.edRemBodyHint),
              style: t.bodyRegular.copyWith(color: s.ink),
            ),

            // Repeat
            label(l10n.edRemRepeat),
            Wrap(
              spacing: SketchSpace.chip,
              runSpacing: SketchSpace.chip,
              children: [
                for (final (value, text) in repeatOptions)
                  SketchChip(
                    label: text,
                    selected: widget.recurrenceType == value,
                    onTap: () => widget.onRecurrenceTypeChanged(value),
                  ),
              ],
            ),

            if (widget.recurrenceType != 'once') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  CircleIconButton(
                    icon: Icons.remove_rounded,
                    semanticLabel: l10n.edRemMoreOften,
                    onPressed: widget.recurrenceInterval > 1
                        ? () => widget.onRecurrenceIntervalChanged(
                            widget.recurrenceInterval - 1)
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      _intervalLabel(l10n, widget.recurrenceInterval),
                      textAlign: TextAlign.center,
                      style: t.cardTitle,
                    ),
                  ),
                  CircleIconButton(
                    icon: Icons.add_rounded,
                    semanticLabel: l10n.edRemLessOften,
                    onPressed: widget.recurrenceInterval < 100
                        ? () => widget.onRecurrenceIntervalChanged(
                            widget.recurrenceInterval + 1)
                        : null,
                  ),
                ],
              ),

              // Ends
              label(l10n.edRemEnds),
              Wrap(
                spacing: SketchSpace.chip,
                runSpacing: SketchSpace.chip,
                children: [
                  for (final (value, text) in endOptions)
                    SketchChip(
                      label: text,
                      selected: widget.recurrenceEndType == value,
                      onTap: () {
                        widget.onRecurrenceEndTypeChanged(value);
                        if (value == 'never') {
                          widget.onRecurrenceEndValueChanged(null);
                        }
                      },
                    ),
                ],
              ),

              if (widget.recurrenceEndType == 'after_occurrences') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _endOccurrencesController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration:
                      InputDecoration(labelText: l10n.remOccurrenceCount),
                  style: t.bodyRegular.copyWith(color: s.ink),
                  onChanged: (value) {
                    widget.onRecurrenceEndValueChanged(
                        value.isEmpty ? null : value);
                  },
                ),
              ] else if (widget.recurrenceEndType == 'on_date') ...[
                const SizedBox(height: 12),
                SketchChip(
                  label: _endDate == null
                      ? l10n.remSelectEndDate
                      : LocalizedDates.fullDate(context, _endDate!),
                  leading: const Icon(Icons.event_rounded),
                  onTap: _pickEndDate,
                ),
              ],

              // Preview of occurrences
              if (_previewOccurrences.isNotEmpty && when != null) ...[
                const SizedBox(height: SketchSpace.section),
                SketchCard(
                  radius: SketchRadius.group,
                  padding: const EdgeInsets.all(SketchSpace.cardPadLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.remPreview(_previewOccurrences.length),
                          style: t.cardTitle),
                      const SizedBox(height: 12),
                      for (final (i, occurrence)
                          in _previewOccurrences.indexed) ...[
                        if (i > 0) const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: SketchPastels.lavender,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: SketchPastels.onPastel,
                                    width: SketchStroke.pastel),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${i + 1}',
                                style: t.caption.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: SketchPastels.onPastel),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                LocalizedDates.dateTime(context, occurrence),
                                style: t.bodySmall.copyWith(color: s.ink),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],

            // What happens to a reminder (honest about the server).
            const SizedBox(height: SketchSpace.section),
            SketchCard(
              pastel: SketchPastels.sky,
              radius: SketchRadius.group,
              padding: const EdgeInsets.all(SketchSpace.cardPadLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(l10n.remDetails,
                            style: t.cardTitle
                                .copyWith(color: SketchPastels.onPastel)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final line in [
                    l10n.edRemInfoServer,
                    l10n.edRemInfoNotifications,
                    l10n.edRemInfoRepeat,
                    l10n.edRemInfoEdit,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: SketchPastels.onPastel,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              line,
                              style: t.bodySmall
                                  .copyWith(color: SketchPastels.onPastel),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _endOccurrencesController.dispose();
    super.dispose();
  }
}

/// The lavender reminder chip ("Today, 6:00 PM", 12/700, clock icon) that
/// opens the reminder picker; an outline "Pick a date and time" chip before a
/// time is set.
class ReminderChip extends StatelessWidget {
  const ReminderChip({super.key, required this.when, required this.onTap});

  final DateTime? when;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;
    final t = context.type;
    final set = when != null;
    final text = set
        ? LocalizedDates.relativeDayTime(context, when!)
        : l10n.edRemPickTime;
    final fg = set ? SketchPastels.onPastel : s.ink;

    return SketchPressable(
      onTap: onTap,
      semanticLabel: set ? l10n.edReminderChipSemantic(text) : text,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: SketchSpace.minTap),
        child: Align(
          widthFactor: 1,
          heightFactor: 1,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: ShapeDecoration(
              color: set ? SketchPastels.lavender : Colors.transparent,
              shape: StadiumBorder(
                side: BorderSide(
                  color: set ? SketchPastels.onPastel : s.outline,
                  width: SketchStroke.pastel,
                ),
              ),
            ),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(set ? Icons.schedule_rounded : Icons.event_rounded,
                      size: 15, color: fg),
                  const SizedBox(width: 7),
                  Text(text,
                      style: t.chip.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
