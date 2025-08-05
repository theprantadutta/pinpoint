import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:pinpoint/screens/archive_screen.dart';
import 'package:pinpoint/screens/trash_screen.dart';
import 'package:pinpoint/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pinpoint/constants/shared_preference_keys.dart';
import 'dart:async';

class HomeScreenTopBar extends StatefulWidget {
  final ValueChanged<String> onSearchChanged;

  const HomeScreenTopBar({super.key, required this.onSearchChanged});

  @override
  State<HomeScreenTopBar> createState() => _HomeScreenTopBarState();
}

class _HomeScreenTopBarState extends State<HomeScreenTopBar>
    with SingleTickerProviderStateMixin {
  bool _isSearchActive = false;
  final _searchController = TextEditingController();
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;

  // Debounce timer for search
  Timer? _debounce;

  // Scope chips: All, Archived, Trash
  String _scope = 'All';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchInputChanged);
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scaleIn = Tween<double>(begin: 0.98, end: 1.0).animate(_fadeIn);
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
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchActive = !_isSearchActive;
      if (_isSearchActive) {
        _controller.forward(from: 0);
      } else {
        _searchController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkTheme = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _isSearchActive
            ? _buildSearchBar(theme)
            : _buildDefaultBar(theme, isDarkTheme),
      ),
    );
  }

  Widget _buildDefaultBar(ThemeData theme, bool isDarkTheme) {
    final titleColor = isDarkTheme ? Colors.white : const Color(0xFF0F172A);
    return Column(
      key: const ValueKey('defaultBar'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PopupMenuButton<String>(
              tooltip: 'More',
              position: PopupMenuPosition.under,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onSelected: (value) {
                if (value == 'archive') {
                  context.push(ArchiveScreen.kRouteName);
                } else if (value == 'trash') {
                  context.push(TrashScreen.kRouteName);
                } else if (value == 'toggle_biometrics') {
                  final current = MyApp.of(context).isBiometricEnabled;
                  MyApp.of(context).changeBiometricEnabledEnabled(!current);
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
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'toggle_biometrics',
                  child: InkWell(
                    onTap: () async {
                      Navigator.of(context).pop();
                      final prefs = await SharedPreferences.getInstance();
                      final current = prefs.getBool(kBiometricKey) ?? false;
                      await prefs.setBool(kBiometricKey, !current);
                      MyApp.of(context).intializeSharedPreferences();
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Biometric lock'),
                        Text(MyApp.of(context).isBiometricEnabled ? 'On' : 'Off'),
                      ],
                    ),
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDarkTheme
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04),
                ),
                child: Icon(Symbols.menu, color: titleColor),
              ),
            ),
            Row(
              children: [
                Icon(Symbols.push_pin,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Pinpoint',
                  style: theme.textTheme.titleLarge?.copyWith(
                    letterSpacing: -0.2,
                    color: titleColor.withOpacity(0.92),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Symbols.search),
              tooltip: 'Search',
              onPressed: _toggleSearch,
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Scope chips row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _scopeChip(theme, 'All', Icons.all_inbox_rounded),
              const SizedBox(width: 8),
              _scopeChip(theme, 'Archived', Icons.archive_rounded),
              const SizedBox(width: 8),
              _scopeChip(theme, 'Trash', Icons.delete_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    final onSurfaceVariant = theme.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.72)
        : Colors.black.withOpacity(0.6);

    return ScaleTransition(
      key: const ValueKey('searchBar'),
      scale: _scaleIn,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: Icon(Symbols.search, color: onSurfaceVariant),
                suffixIcon: IconButton(
                  icon: Icon(Symbols.close, color: onSurfaceVariant),
                  onPressed: _searchController.clear,
                  tooltip: 'Clear',
                ),
                border: InputBorder.none,
                filled: true,
                fillColor: theme.cardColor,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.transparent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
              ),
              style: theme.textTheme.bodyLarge,
              textInputAction: TextInputAction.search,
            ),
          ),
          IconButton(
            icon: const Icon(Symbols.close),
            tooltip: 'Close',
            onPressed: _toggleSearch,
          ),
        ],
      ),
    );
  }

  Widget _scopeChip(ThemeData theme, String label, IconData icon) {
    final selected = _scope == label;
    final dark = theme.brightness == Brightness.dark;
    final bg = selected
        ? theme.colorScheme.primary.withOpacity(dark ? 0.18 : 0.14)
        : (dark ? Colors.white : Colors.black).withOpacity(0.06);
    final fg = selected
        ? theme.colorScheme.primary
        : (dark ? Colors.white : Colors.black).withOpacity(0.72);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        setState(() => _scope = label);
        // When scope changes, we can trigger a synthetic search update.
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 80), () {
          widget.onSearchChanged(_searchController.text);
        });
        // Optional: Navigate to archive/trash when selecting those scopes.
        if (label == 'Archived') {
          context.push(ArchiveScreen.kRouteName);
        } else if (label == 'Trash') {
          context.push(TrashScreen.kRouteName);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: (dark ? Colors.white : Colors.black).withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: fg,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
