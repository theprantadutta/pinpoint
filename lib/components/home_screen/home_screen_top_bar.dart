import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:pinpoint/screens/archive_screen.dart';
import 'package:pinpoint/screens/trash_screen.dart';

class HomeScreenTopBar extends StatefulWidget {
  final ValueChanged<String> onSearchChanged;

  const HomeScreenTopBar({super.key, required this.onSearchChanged});

  @override
  State<HomeScreenTopBar> createState() => _HomeScreenTopBarState();
}

class _HomeScreenTopBarState extends State<HomeScreenTopBar> {
  bool _isSearchActive = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      widget.onSearchChanged(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchActive = !_isSearchActive;
      if (!_isSearchActive) {
        _searchController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkTheme = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
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
    return Row(
      key: const ValueKey('defaultBar'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PopupMenuButton<String>(
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
        ),
        Text(
          'PinPoint',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.3,
            color: isDarkTheme ? Colors.grey.shade300 : Colors.grey.shade600,
          ),
        ),
        IconButton(
          icon: Icon(Symbols.search),
          onPressed: _toggleSearch,
        ),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Row(
      key: const ValueKey('searchBar'),
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search notes...',
              prefixIcon: Icon(Symbols.search, color: theme.colorScheme.onSurfaceVariant),
              suffixIcon: IconButton(
                icon: Icon(Symbols.close, color: theme.colorScheme.onSurfaceVariant),
                onPressed: _searchController.clear,
              ),
              border: InputBorder.none,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: Colors.transparent),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
            ),
            style: theme.textTheme.bodyLarge,
          ),
        ),
        IconButton(
          icon: Icon(Symbols.close),
          onPressed: _toggleSearch,
        ),
      ],
    );
  }
}