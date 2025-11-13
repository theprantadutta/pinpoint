import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/filter_options.dart';
import '../services/filter_service.dart';
import '../database/database.dart';
import '../service_locators/init_service_locators.dart';

/// Comprehensive filter bottom sheet for notes
class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late FilterOptions _tempFilters;
  List<NoteFolder> _availableFolders = [];
  bool _isLoadingFolders = true;

  static const Map<String, String> _noteTypeLabels = {
    'text': 'Text Notes',
    'audio': 'Audio Notes',
    'reminder': 'Reminders',
  };

  static const Map<String, IconData> _noteTypeIcons = {
    'text': Icons.text_fields,
    'audio': Icons.mic,
    'reminder': Icons.notifications_active,
  };

  @override
  void initState() {
    super.initState();
    final filterService = context.read<FilterService>();
    _tempFilters = filterService.filterOptions;
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    try {
      final database = getIt<AppDatabase>();
      final folders = await database.select(database.noteFolders).get();
      setState(() {
        _availableFolders = folders;
        _isLoadingFolders = false;
      });
    } catch (e) {
      debugPrint('Error loading folders: $e');
      setState(() => _isLoadingFolders = false);
    }
  }

  void _updateFilters(FilterOptions newFilters) {
    setState(() {
      _tempFilters = newFilters;
    });
  }

  void _applyFilters() {
    final filterService = context.read<FilterService>();
    filterService.updateFilters(_tempFilters);
    Navigator.pop(context);
  }

  void _clearFilters() {
    final filterService = context.read<FilterService>();
    filterService.clearFilters();
    Navigator.pop(context);
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _tempFilters.dateRangeStart != null &&
              _tempFilters.dateRangeEnd != null
          ? DateTimeRange(
              start: _tempFilters.dateRangeStart!,
              end: _tempFilters.dateRangeEnd!,
            )
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Theme.of(context).colorScheme.primary,
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _updateFilters(_tempFilters.copyWith(
        dateRangeStart: picked.start,
        dateRangeEnd: picked.end,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.filter_list, color: cs.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Filters',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (_tempFilters.hasActiveFilters)
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('Clear All'),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Filter content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Pinned only toggle
                    Card(
                      child: SwitchListTile(
                        title: Row(
                          children: [
                            Icon(Icons.push_pin, color: cs.primary, size: 20),
                            const SizedBox(width: 12),
                            const Text('Pinned Notes Only'),
                          ],
                        ),
                        value: _tempFilters.pinsOnly,
                        onChanged: (value) {
                          _updateFilters(
                              _tempFilters.copyWith(pinsOnly: value));
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Note types
                    Text(
                      'Note Types',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(
                        children: _noteTypeLabels.entries.map((entry) {
                          final isSelected =
                              _tempFilters.noteTypes.contains(entry.key);
                          return CheckboxListTile(
                            title: Row(
                              children: [
                                Icon(
                                  _noteTypeIcons[entry.key],
                                  color: cs.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(entry.value),
                              ],
                            ),
                            value: isSelected,
                            onChanged: (checked) {
                              final newTypes =
                                  List<String>.from(_tempFilters.noteTypes);
                              if (checked == true) {
                                newTypes.add(entry.key);
                              } else {
                                newTypes.remove(entry.key);
                              }
                              _updateFilters(
                                  _tempFilters.copyWith(noteTypes: newTypes));
                            },
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Date range
                    Text(
                      'Date Range',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.calendar_today, color: cs.primary),
                        title: Text(
                          _tempFilters.dateRangeStart != null &&
                                  _tempFilters.dateRangeEnd != null
                              ? '${_formatDate(_tempFilters.dateRangeStart!)} - ${_formatDate(_tempFilters.dateRangeEnd!)}'
                              : 'Select date range',
                        ),
                        subtitle: _tempFilters.dateRangeStart != null
                            ? const Text('Tap to change, long press to clear')
                            : null,
                        trailing: _tempFilters.dateRangeStart != null
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _updateFilters(_tempFilters.copyWith(
                                      clearDateRange: true));
                                },
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: _selectDateRange,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Folders
                    Text(
                      'Folders',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingFolders)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_availableFolders.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.folder_outlined,
                                  color: cs.onSurface.withValues(alpha: 0.5)),
                              const SizedBox(width: 12),
                              Text(
                                'No folders available',
                                style: TextStyle(
                                    color: cs.onSurface.withValues(alpha: 0.5)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableFolders.map((folder) {
                          final isSelected = _tempFilters.folderIds
                              .contains(folder.noteFolderId);
                          return FilterChip(
                            avatar: Icon(
                              Icons.folder,
                              size: 18,
                              color: isSelected ? cs.onPrimary : cs.primary,
                            ),
                            label: Text(folder.noteFolderTitle),
                            selected: isSelected,
                            onSelected: (selected) {
                              final newFolderIds =
                                  List<int>.from(_tempFilters.folderIds);
                              if (selected) {
                                newFolderIds.add(folder.noteFolderId);
                              } else {
                                newFolderIds.remove(folder.noteFolderId);
                              }
                              _updateFilters(_tempFilters.copyWith(
                                  folderIds: newFolderIds));
                            },
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 80), // Space for apply button
                  ],
                ),
              ),

              // Apply button (fixed at bottom)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(
                    top: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                  ),
                ),
                child: FilledButton(
                  onPressed: _applyFilters,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: Text(
                    _tempFilters.hasActiveFilters
                        ? 'Apply ${_tempFilters.activeFilterCount} Filter${_tempFilters.activeFilterCount > 1 ? 's' : ''}'
                        : 'Apply Filters',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
