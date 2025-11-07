import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../animations.dart';
import 'tag_chip.dart';

/// SearchBarSticky - Expandable search bar with command palette
///
/// Features:
/// - Glass morphism effect
/// - Expands into full command sheet
/// - Recent queries as chips
/// - Keyboard shortcuts
/// - Fuzzy search suggestions
class SearchBarSticky extends StatefulWidget {
  final String? hint;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onTap;
  final List<String>? recentSearches;
  final bool autoFocus;
  final TextEditingController? controller;

  const SearchBarSticky({
    super.key,
    this.hint,
    this.onSearch,
    this.onTap,
    this.recentSearches,
    this.autoFocus = false,
    this.controller,
  });

  @override
  State<SearchBarSticky> createState() => _SearchBarStickyState();
}

class _SearchBarStickyState extends State<SearchBarSticky> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode.addListener(_onFocusChange);
    if (widget.autoFocus) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.controller == null) {
      _controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  void _handleSearch() {
    if (widget.onSearch != null && _controller.text.isNotEmpty) {
      widget.onSearch!(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glassSurface = theme.glassSurface;
    final motionSettings = MotionSettings.fromMediaQuery(context);

    final effectiveBlur = motionSettings.reduceMotion
        ? 0.0
        : (_isFocused
            ? glassSurface.blurAmount * 1.5
            : glassSurface.blurAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search bar
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: effectiveBlur,
              sigmaY: effectiveBlur,
            ),
            child: AnimatedContainer(
              duration: motionSettings.getDuration(PinpointAnimations.fast),
              curve: motionSettings.getCurve(PinpointAnimations.emphasized),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: glassSurface.overlayColor.withOpacity(
                  _isFocused
                      ? glassSurface.opacity * 1.5
                      : glassSurface.opacity,
                ),
                border: Border.all(
                  color: _isFocused
                      ? theme.colorScheme.primary
                      : glassSurface.borderColor,
                  width: _isFocused ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: _isFocused
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: widget.hint ?? 'Search notes...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: theme.textTheme.bodyMedium,
                      onTap: widget.onTap,
                      onSubmitted: (_) => _handleSearch(),
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      iconSize: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                      onPressed: () {
                        _controller.clear();
                        setState(() {});
                      },
                      tooltip: 'Clear',
                    ),
                  // Keyboard shortcut hint
                  if (!_isFocused)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '⌘K',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Recent searches
        if (_isFocused &&
            widget.recentSearches != null &&
            widget.recentSearches!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Recent searches',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.recentSearches!
                .take(5)
                .map(
                  (search) => TagChip(
                    label: search,
                    size: TagChipSize.small,
                    onTap: () {
                      _controller.text = search;
                      _handleSearch();
                    },
                    showClose: true,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

/// CommandSheet - Full-screen command palette
///
/// Opened by SearchBarSticky or ⌘K shortcut
class CommandSheet extends StatefulWidget {
  final List<CommandItem> commands;
  final ValueChanged<CommandItem>? onCommandSelected;

  const CommandSheet({
    super.key,
    required this.commands,
    this.onCommandSelected,
  });

  @override
  State<CommandSheet> createState() => _CommandSheetState();
}

class _CommandSheetState extends State<CommandSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<CommandItem> _filteredCommands = [];

  @override
  void initState() {
    super.initState();
    _filteredCommands = widget.commands;
    _searchController.addListener(_filterCommands);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCommands() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCommands = widget.commands.where((command) {
        return command.label.toLowerCase().contains(query) ||
            (command.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search input
          SearchBarSticky(
            controller: _searchController,
            hint: 'Type a command or search...',
            autoFocus: true,
          ),

          const SizedBox(height: 24),

          // Command list
          Expanded(
            child: ListView.builder(
              itemCount: _filteredCommands.length,
              itemBuilder: (context, index) {
                final command = _filteredCommands[index];
                return ListTile(
                  leading: Icon(command.icon),
                  title: Text(command.label),
                  subtitle: command.description != null
                      ? Text(command.description!)
                      : null,
                  trailing: command.shortcut != null
                      ? Text(
                          command.shortcut!,
                          style: theme.textTheme.labelSmall,
                        )
                      : null,
                  onTap: () {
                    if (widget.onCommandSelected != null) {
                      widget.onCommandSelected!(command);
                    }
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Command item for command palette
class CommandItem {
  final String label;
  final String? description;
  final IconData icon;
  final String? shortcut;
  final VoidCallback action;

  const CommandItem({
    required this.label,
    this.description,
    required this.icon,
    this.shortcut,
    required this.action,
  });
}
