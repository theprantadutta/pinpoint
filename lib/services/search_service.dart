import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing search state and history
class SearchService extends ChangeNotifier {
  static const String _historyKey = 'search_history';
  static const int _maxHistoryItems = 10;

  String _currentQuery = '';
  List<String> _searchHistory = [];
  bool _searchInContent = true; // Search in content by default
  bool _isInitialized = false;

  /// Current search query
  String get currentQuery => _currentQuery;

  /// Whether to search in note content (not just title)
  bool get searchInContent => _searchInContent;

  /// Recent search history
  List<String> get searchHistory => List.unmodifiable(_searchHistory);

  /// Whether there's an active search
  bool get hasActiveSearch => _currentQuery.isNotEmpty;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_historyKey);
      if (history != null) {
        _searchHistory = history;
      }
      _isInitialized = true;
      debugPrint('✅ [SearchService] Initialized with ${_searchHistory.length} history items');
    } catch (e) {
      debugPrint('⚠️ [SearchService] Failed to load history: $e');
    }
  }

  /// Update the current search query
  void setQuery(String query) {
    final trimmed = query.trim();
    if (_currentQuery == trimmed) return;

    _currentQuery = trimmed;
    notifyListeners();
  }

  /// Toggle content search
  void setSearchInContent(bool value) {
    if (_searchInContent == value) return;
    _searchInContent = value;
    notifyListeners();
  }

  /// Add a query to search history
  Future<void> addToHistory(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || trimmed.length < 2) return;

    // Remove if already exists (to move to top)
    _searchHistory.remove(trimmed);

    // Add to beginning
    _searchHistory.insert(0, trimmed);

    // Limit history size
    if (_searchHistory.length > _maxHistoryItems) {
      _searchHistory = _searchHistory.take(_maxHistoryItems).toList();
    }

    // Persist
    await _saveHistory();
    notifyListeners();
  }

  /// Remove an item from history
  Future<void> removeFromHistory(String query) async {
    if (_searchHistory.remove(query)) {
      await _saveHistory();
      notifyListeners();
    }
  }

  /// Clear all search history
  Future<void> clearHistory() async {
    _searchHistory.clear();
    await _saveHistory();
    notifyListeners();
    debugPrint('🧹 [SearchService] Cleared search history');
  }

  /// Clear current search
  void clearSearch() {
    if (_currentQuery.isEmpty) return;
    _currentQuery = '';
    notifyListeners();
  }

  /// Perform search - adds to history if query is valid
  Future<void> performSearch(String query) async {
    setQuery(query);
    if (query.trim().length >= 2) {
      await addToHistory(query);
    }
  }

  /// Save history to SharedPreferences
  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_historyKey, _searchHistory);
    } catch (e) {
      debugPrint('⚠️ [SearchService] Failed to save history: $e');
    }
  }

  /// Check if a note matches the search query
  /// Returns true if the note title or content matches
  bool matchesSearch({
    required String? title,
    required String? content,
    String? query,
  }) {
    final searchQuery = (query ?? _currentQuery).toLowerCase().trim();
    if (searchQuery.isEmpty) return true;

    // Always search in title
    if (title != null && title.toLowerCase().contains(searchQuery)) {
      return true;
    }

    // Optionally search in content
    if (_searchInContent && content != null) {
      return content.toLowerCase().contains(searchQuery);
    }

    return false;
  }

  /// Highlight matching text in a string
  /// Returns a list of TextSpan-like objects for building highlighted text
  List<SearchMatch> highlightMatches(String text, {String? query}) {
    final searchQuery = (query ?? _currentQuery).toLowerCase().trim();
    if (searchQuery.isEmpty) {
      return [SearchMatch(text: text, isMatch: false)];
    }

    final matches = <SearchMatch>[];
    final lowerText = text.toLowerCase();
    int lastEnd = 0;

    int index = lowerText.indexOf(searchQuery);
    while (index != -1) {
      // Add non-matching text before this match
      if (index > lastEnd) {
        matches.add(SearchMatch(
          text: text.substring(lastEnd, index),
          isMatch: false,
        ));
      }

      // Add the matching text
      matches.add(SearchMatch(
        text: text.substring(index, index + searchQuery.length),
        isMatch: true,
      ));

      lastEnd = index + searchQuery.length;
      index = lowerText.indexOf(searchQuery, lastEnd);
    }

    // Add remaining text after last match
    if (lastEnd < text.length) {
      matches.add(SearchMatch(
        text: text.substring(lastEnd),
        isMatch: false,
      ));
    }

    return matches.isEmpty
        ? [SearchMatch(text: text, isMatch: false)]
        : matches;
  }
}

/// Represents a segment of text that may or may not match a search query
class SearchMatch {
  final String text;
  final bool isMatch;

  const SearchMatch({
    required this.text,
    required this.isMatch,
  });

  @override
  String toString() => 'SearchMatch(text: "$text", isMatch: $isMatch)';
}
