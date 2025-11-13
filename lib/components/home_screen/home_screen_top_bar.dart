import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:pinpoint/screens/archive_screen.dart';
import 'package:pinpoint/screens/trash_screen.dart';
import 'package:pinpoint/screens/my_folders_screen.dart';
import 'package:pinpoint/screens/subscription_screen.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../design_system/design_system.dart';
import '../../services/filter_service.dart';
import '../../widgets/filter_bottom_sheet.dart';
import '../../sync/sync_manager.dart';
import '../../service_locators/init_service_locators.dart';

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
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return PopupMenuButton<String>(
      tooltip: 'More',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: dark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.95)
          : cs.surface.withValues(alpha: 0.98),
      elevation: 8,
      onSelected: (value) async {
        if (value == 'archive') {
          context.push(ArchiveScreen.kRouteName);
        } else if (value == 'trash') {
          context.push(TrashScreen.kRouteName);
        } else if (value == 'folders') {
          context.push(MyFoldersScreen.kRouteName);
        } else if (value == 'sync') {
          // Trigger manual sync
          await _performManualSync(context);
        } else if (value == 'premium') {
          context.push(SubscriptionScreen.kRouteName);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        _buildMenuItem(
          context: context,
          value: 'folders',
          icon: Symbols.folder,
          label: 'My Folders',
          color: cs.primary,
        ),
        _buildMenuItem(
          context: context,
          value: 'archive',
          icon: Symbols.archive,
          label: 'Archived',
          color: cs.tertiary,
        ),
        _buildMenuItem(
          context: context,
          value: 'trash',
          icon: Symbols.delete,
          label: 'Trash',
          color: cs.error,
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          context: context,
          value: 'sync',
          icon: Symbols.sync,
          label: 'Sync Now',
          color: cs.secondary,
        ),
        _buildMenuItem(
          context: context,
          value: 'premium',
          icon: Symbols.workspace_premium,
          label: 'Upgrade to Premium',
          color: Color(0xFFFFD700), // Gold color
          fill: 1,
        ),
      ],
      child: GlassContainer(
        padding: const EdgeInsets.all(8),
        borderRadius: 12,
        child: const Icon(Symbols.menu),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem({
    required BuildContext context,
    required String value,
    required IconData icon,
    required String label,
    required Color color,
    double fill = 0,
  }) {
    final theme = Theme.of(context);

    return PopupMenuItem<String>(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color.withValues(alpha: 0.15),
            ),
            child: Center(
              child: Icon(
                icon,
                color: color,
                size: 20,
                fill: fill,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performManualSync(BuildContext context) async {
    if (!context.mounted) return;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final messenger = ScaffoldMessenger.of(context);

    // Show loading indicator
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(cs.onInverseSurface),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Syncing...'),
          ],
        ),
        duration: const Duration(seconds: 10),
        backgroundColor: cs.inverseSurface,
      ),
    );

    try {
      final syncManager = getIt<SyncManager>();
      final result = await syncManager.sync();

      if (!context.mounted) return;

      // Hide loading snackbar
      messenger.hideCurrentSnackBar();

      final totalSynced =
          result.notesSynced + result.foldersSynced + result.tagsSynced;

      // Show success message
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Symbols.check_circle,
                color: cs.onInverseSurface,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                result.success
                    ? (totalSynced > 0
                        ? 'Synced ${result.notesSynced} notes, ${result.foldersSynced} folders'
                        : 'Already up to date')
                    : result.message,
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: cs.inverseSurface,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      // Hide loading snackbar
      messenger.hideCurrentSnackBar();

      // Show error message
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Symbols.error,
                color: cs.onErrorContainer,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Sync failed: ${e.toString()}'),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
          backgroundColor: cs.errorContainer,
        ),
      );
    }
  }
}
