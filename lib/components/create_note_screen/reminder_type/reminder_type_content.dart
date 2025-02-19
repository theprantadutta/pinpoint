// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReminderTypeContent extends StatefulWidget {
  const ReminderTypeContent({super.key});

  @override
  State<ReminderTypeContent> createState() => _ReminderTypeContentState();
}

class _ReminderTypeContentState extends State<ReminderTypeContent> {
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _selectedDateTime;

  Future<void> _pickDateTime() async {
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
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    return SliverToBoxAdapter(
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.59,
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 20,
        ),
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: kPrimaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Reminder Details",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "Enter a brief description...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickDateTime,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border:
                      Border.all(color: kPrimaryColor.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDateTime == null
                          ? "Select Reminder Time"
                          : DateFormat("d MMM, yy 'at' hh:mm a")
                              .format(_selectedDateTime!),
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    Icon(Icons.calendar_today, color: kPrimaryColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
