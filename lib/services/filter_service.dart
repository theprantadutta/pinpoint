import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/filter_options.dart';

/// Service for managing note filter state with persistence
class FilterService extends ChangeNotifier {
  static const String _filterKey = 'note_filter_options';

  FilterOptions _filterOptions = FilterOptions.empty;
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  FilterOptions get filterOptions => _filterOptions;
  bool get hasActiveFilters => _filterOptions.hasActiveFilters;
  int get activeFilterCount => _filterOptions.activeFilterCount;

  /// Initialize the service and load saved filters
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⏭️ [FilterService] Already initialized, skipping...');
      return;
    }

    _prefs = await SharedPreferences.getInstance();
    await _loadFilters();
    _isInitialized = true;
    debugPrint('✅ [FilterService] Initialized with filters: $_filterOptions');
  }

  /// Load filters from SharedPreferences
  Future<void> _loadFilters() async {
    final encodedFilters = _prefs?.getString(_filterKey);
    if (encodedFilters != null) {
      _filterOptions = FilterOptions.decode(encodedFilters);
      notifyListeners();
    }
  }

  /// Save filters to SharedPreferences
  Future<void> _saveFilters() async {
    await _prefs?.setString(_filterKey, _filterOptions.encode());
    debugPrint('💾 [FilterService] Saved filters: $_filterOptions');
  }

  /// Update filter options
  Future<void> updateFilters(FilterOptions newFilters) async {
    if (_filterOptions == newFilters) return;

    _filterOptions = newFilters;
    notifyListeners();
    await _saveFilters();
    debugPrint('🔄 [FilterService] Updated filters: $_filterOptions');
  }

  /// Update folder filter
  Future<void> setFolderIds(List<int> folderIds) async {
    await updateFilters(_filterOptions.copyWith(folderIds: folderIds));
  }

  /// Update note types filter
  Future<void> setNoteTypes(List<String> noteTypes) async {
    await updateFilters(_filterOptions.copyWith(noteTypes: noteTypes));
  }

  /// Update date range filter
  Future<void> setDateRange(DateTime? start, DateTime? end) async {
    await updateFilters(_filterOptions.copyWith(
      dateRangeStart: start,
      dateRangeEnd: end,
      clearDateRange: start == null && end == null,
    ));
  }

  /// Update pins only filter
  Future<void> setPinsOnly(bool pinsOnly) async {
    await updateFilters(_filterOptions.copyWith(pinsOnly: pinsOnly));
  }

  /// Clear all filters
  Future<void> clearFilters() async {
    await updateFilters(FilterOptions.empty);
    debugPrint('🧹 [FilterService] Cleared all filters');
  }

  /// Clear specific filter
  Future<void> clearFolderFilter() async {
    await updateFilters(_filterOptions.copyWith(folderIds: []));
  }

  Future<void> clearNoteTypeFilter() async {
    await updateFilters(_filterOptions.copyWith(noteTypes: []));
  }

  Future<void> clearDateRangeFilter() async {
    await updateFilters(_filterOptions.copyWith(clearDateRange: true));
  }

  Future<void> clearPinsFilter() async {
    await updateFilters(_filterOptions.copyWith(pinsOnly: false));
  }
}
