import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:pinpoint/screens/archive_screen.dart';
import 'package:pinpoint/screens/trash_screen.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../design_system/design_system.dart';
import '../../services/filter_service.dart';
import '../../widgets/filter_bottom_sheet.dart';

class HomeScreenTopBar extends StatefulWidget {
  final ValueChanged<String> onSearchChanged;

  const HomeScreenTopBar({super.key, required this.onSearchChanged});

  @override
  State<HomeScreenTopBar> createState() => _HomeScreenTopBarState();
}

class _HomeScreenTopBarState extends State<HomeScreenTopBar> {
  bool _isSearchActive = false;
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchInputChanged);
  }

  void _onSearchInputChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      widget.onSearchChanged(_searchController.text);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: Menu, Logo, and Search trigger
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Menu button
              _buildMenuButton(context, theme),

              // Logo
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.2),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/pinpoint-logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Pinpoint',
                    style: theme.textTheme.titleLarge?.copyWith(
                      letterSpacing: -0.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),

              // Filter and Search buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Filter button with badge
                  Consumer<FilterService>(
                    builder: (context, filterService, _) {
                      final hasFilters = filterService.hasActiveFilters;
                      final filterCount = filterService.activeFilterCount;

                      return Badge(
                        isLabelVisible: hasFilters,
                        label: Text(filterCount.toString()),
                        child: IconButton(
                          icon: Icon(
                            hasFilters
                                ? Symbols.filter_alt
                                : Symbols.filter_alt,
                            fill: hasFilters ? 1 : 0,
                          ),
                          tooltip: 'Filters',
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => const FilterBottomSheet(),
                            );
                          },
                        ),
                      );
                    },
                  ),

                  // Search toggle button
                  IconButton(
                    icon: const Icon(Symbols.search),
                    tooltip: 'Search',
                    onPressed: () {
                      setState(() => _isSearchActive = !_isSearchActive);
                    },
                  ),
                ],
              ),
            ],
          ),

          // Search bar (expandable)
          if (_isSearchActive) ...[
            const SizedBox(height: 12),
            SearchBarSticky(
              controller: _searchController,
              hint: 'Search notes...',
              onSearch: widget.onSearchChanged,
              autoFocus: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, ThemeData theme) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      onSelected: (value) {
        if (value == 'archive') {
          context.push(ArchiveScreen.kRouteName);
        } else if (value == 'trash') {
          context.push(TrashScreen.kRouteName);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'archive',
          child: Text('Archived'),
        ),
        const PopupMenuItem<String>(
          value: 'trash',
          child: Text('Trash'),
        ),
      ],
      child: GlassContainer(
        padding: const EdgeInsets.all(8),
        borderRadius: 12,
        child: const Icon(Symbols.menu),
      ),
    );
  }
}
