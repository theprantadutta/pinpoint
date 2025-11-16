import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

/// Configuration for different note types
/// Defines colors, icons, and display properties for each type
class NoteTypeConfig {
  final String type;
  final String displayName;
  final IconData icon;
  final Color color;
  final Color lightColor;

  const NoteTypeConfig({
    required this.type,
    required this.displayName,
    required this.icon,
    required this.color,
    required this.lightColor,
  });

  /// Text/Content Note
  static const text = NoteTypeConfig(
    type: 'text',
    displayName: 'Text Note',
    icon: Symbols.edit_note,
    color: Color(0xFF3B82F6), // Blue
    lightColor: Color(0xFFDBEAFE),
  );

  /// Todo List Note
  static const todo = NoteTypeConfig(
    type: 'todo',
    displayName: 'Todo List',
    icon: Symbols.check_box,
    color: Color(0xFF8B5CF6), // Purple
    lightColor: Color(0xFFEDE9FE),
  );

  /// Voice/Audio Note
  static const voice = NoteTypeConfig(
    type: 'voice',
    displayName: 'Voice Note',
    icon: Symbols.mic,
    color: Color(0xFF10B981), // Green
    lightColor: Color(0xFFD1FAE5),
  );

  /// Reminder Note
  static const reminder = NoteTypeConfig(
    type: 'reminder',
    displayName: 'Reminder',
    icon: Symbols.alarm,
    color: Color(0xFFF59E0B), // Orange
    lightColor: Color(0xFFFEF3C7),
  );

  /// Get config by note type string
  static NoteTypeConfig fromType(String type) {
    switch (type) {
      case 'text':
        return NoteTypeConfig.text;
      case 'todo':
      case 'todo_list':
        return NoteTypeConfig.todo;
      case 'voice':
      case 'audio':
        return NoteTypeConfig.voice;
      case 'reminder':
        return NoteTypeConfig.reminder;
      default:
        return NoteTypeConfig.text;
    }
  }

  /// All note types
  static const List<NoteTypeConfig> all = [
    text,
    todo,
    voice,
    reminder,
  ];
}
