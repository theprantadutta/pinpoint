import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../design_system/design_system.dart';
import '../../services/filter_service.dart';
import '../../services/connectivity_service.dart';
import '../../widgets/filter_bottom_sheet.dart';
import '../../walkthrough/walkthrough_keys.dart';

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
          // Top row: [Menu, Connectivity] · Logo · [Filter, Search]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left group: menu + connectivity status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMenuButton(context, theme),
                  _buildConnectivityIndicator(context, theme),
                ],
              ),

              // Logo (flexible so it never overflows on narrow screens)
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.2),
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
                    Flexible(
                      child: Text(
                        'Pinpoint',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          letterSpacing: -0.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
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
                          visualDensity: VisualDensity.compact,
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
                    key: WalkthroughKeys.searchKey,
                    visualDensity: VisualDensity.compact,
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

  /// Always-visible connectivity status: subtle when online, highlighted when
  /// offline. Kept compact so the app bar stays balanced and responsive.
  Widget _buildConnectivityIndicator(BuildContext context, ThemeData theme) {
    final cs = theme.colorScheme;
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, _) {
        final offline = connectivity.isOffline;
        // Pure status indicator — no tap action, just a colored icon.
        return Tooltip(
          message: offline
              ? 'Offline — changes are saved and will sync when you reconnect'
              : 'Online',
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              offline ? Symbols.cloud_off : Symbols.cloud_done,
              fill: offline ? 1 : 0,
              color: offline ? cs.error : cs.primary,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuButton(BuildContext context, ThemeData theme) {
    // Opens the Keep-style navigation drawer hosted by the home Scaffold.
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: const Icon(Symbols.menu),
      tooltip: 'Menu',
      onPressed: () => Scaffold.of(context).openDrawer(),
    );
  }
}
