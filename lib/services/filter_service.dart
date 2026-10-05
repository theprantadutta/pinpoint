import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/shared_preference_keys.dart';
import '../models/filter_options.dart';

/// How note lists are ordered (Filters → "Sort by").
enum NoteSort {
  lastEdited('updatedAt'),
  dateCreated('createdAt'),
  titleAz('title');

  const NoteSort(this.key);

  /// The value persisted under [kHomeScreenSortTypeKey].
  final String key;

  static NoteSort fromKey(String? key) => values.firstWhere(
        (s) => s.key == key,
        orElse: () => NoteSort.lastEdited,
      );
}

/// Service for managing note filter state with persistence
class FilterService extends ChangeNotifier {
  static const String _filterKey = 'note_filter_options';

  FilterOptions _filterOptions = FilterOptions.empty;
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  NoteSort _sort = NoteSort.lastEdited;

  FilterOptions get filterOptions => _filterOptions;
  NoteSort get sort => _sort;
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
    _sort = NoteSort.fromKey(_prefs?.getString(kHomeScreenSortTypeKey));
    _isInitialized = true;
    notifyListeners();
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

  /// Update the sort order. Sorting is not a filter: it is kept out of
  /// [hasActiveFilters] and survives [clearFilters].
  Future<void> setSort(NoteSort sort) async {
    if (_sort == sort) return;
    _sort = sort;
    notifyListeners();
    await _prefs?.setString(kHomeScreenSortTypeKey, sort.key);
  }

  Future<void> setIncludeArchived(bool includeArchived) async {
    await updateFilters(
        _filterOptions.copyWith(includeArchived: includeArchived));
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
