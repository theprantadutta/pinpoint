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
          // Keep-style search bar: [hamburger] [ Search your notes ] [filter]
          Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Symbols.menu),
                  tooltip: 'Menu',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: _isSearchActive
                    ? SearchBarSticky(
                        controller: _searchController,
                        hint: 'Search your notes',
                        onSearch: widget.onSearchChanged,
                        autoFocus: true,
                      )
                    : _buildSearchPill(context, theme),
              ),
              const SizedBox(width: 4),
              _buildConnectivityIndicator(context, theme),
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
                        Symbols.filter_alt,
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
            ],
          ),
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

  /// Tappable "Search your notes" pill (Keep-style). Tapping reveals an inline
  /// search field in its place.
  Widget _buildSearchPill(BuildContext context, ThemeData theme) {
    final cs = theme.colorScheme;
    return Material(
      key: WalkthroughKeys.searchKey,
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() => _isSearchActive = true),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Symbols.search, size: 22, color: cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search your notes',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
