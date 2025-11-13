import 'dart:convert';

/// Model for managing note search and filter options
class FilterOptions {
  final List<int> folderIds;
  final List<String> noteTypes; // ['text', 'audio', 'todo', 'reminder']
  final DateTime? dateRangeStart;
  final DateTime? dateRangeEnd;
  final bool pinsOnly;

  const FilterOptions({
    this.folderIds = const [],
    this.noteTypes = const [],
    this.dateRangeStart,
    this.dateRangeEnd,
    this.pinsOnly = false,
  });

  /// Default filter options (no filters applied)
  static const FilterOptions empty = FilterOptions();

  /// Check if any filters are active
  bool get hasActiveFilters {
    return folderIds.isNotEmpty ||
        noteTypes.isNotEmpty ||
        dateRangeStart != null ||
        dateRangeEnd != null ||
        pinsOnly;
  }

  /// Count of active filters (for badge display)
  int get activeFilterCount {
    int count = 0;
    if (folderIds.isNotEmpty) count++;
    if (noteTypes.isNotEmpty) count++;
    if (dateRangeStart != null || dateRangeEnd != null) count++;
    if (pinsOnly) count++;
    return count;
  }

  /// Create a copy with updated fields
  FilterOptions copyWith({
    List<int>? folderIds,
    List<String>? noteTypes,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
    bool? pinsOnly,
    bool clearDateRange = false,
  }) {
    return FilterOptions(
      folderIds: folderIds ?? this.folderIds,
      noteTypes: noteTypes ?? this.noteTypes,
      dateRangeStart:
          clearDateRange ? null : (dateRangeStart ?? this.dateRangeStart),
      dateRangeEnd: clearDateRange ? null : (dateRangeEnd ?? this.dateRangeEnd),
      pinsOnly: pinsOnly ?? this.pinsOnly,
    );
  }

  /// Clear all filters
  FilterOptions clear() {
    return FilterOptions.empty;
  }

  /// Serialize to JSON for SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'folderIds': folderIds,
      'noteTypes': noteTypes,
      'dateRangeStart': dateRangeStart?.toIso8601String(),
      'dateRangeEnd': dateRangeEnd?.toIso8601String(),
      'pinsOnly': pinsOnly,
    };
  }

  /// Deserialize from JSON
  factory FilterOptions.fromJson(Map<String, dynamic> json) {
    return FilterOptions(
      folderIds: (json['folderIds'] as List<dynamic>?)?.cast<int>() ?? [],
      noteTypes: (json['noteTypes'] as List<dynamic>?)?.cast<String>() ?? [],
      dateRangeStart: json['dateRangeStart'] != null
          ? DateTime.parse(json['dateRangeStart'] as String)
          : null,
      dateRangeEnd: json['dateRangeEnd'] != null
          ? DateTime.parse(json['dateRangeEnd'] as String)
          : null,
      pinsOnly: json['pinsOnly'] as bool? ?? false,
    );
  }

  /// Encode to string for SharedPreferences storage
  String encode() {
    return jsonEncode(toJson());
  }

  /// Decode from string
  static FilterOptions decode(String encodedString) {
    try {
      final json = jsonDecode(encodedString) as Map<String, dynamic>;
      return FilterOptions.fromJson(json);
    } catch (e) {
      return FilterOptions.empty;
    }
  }

  @override
  String toString() {
    return 'FilterOptions(folderIds: $folderIds, noteTypes: $noteTypes, '
        'dateRange: ${dateRangeStart != null || dateRangeEnd != null ? '${dateRangeStart?.toIso8601String()} - ${dateRangeEnd?.toIso8601String()}' : 'none'}, '
        'pinsOnly: $pinsOnly)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilterOptions &&
        _listEquals(other.folderIds, folderIds) &&
        _listEquals(other.noteTypes, noteTypes) &&
        other.dateRangeStart == dateRangeStart &&
        other.dateRangeEnd == dateRangeEnd &&
        other.pinsOnly == pinsOnly;
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(folderIds),
      Object.hashAll(noteTypes),
      dateRangeStart,
      dateRangeEnd,
      pinsOnly,
    );
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
