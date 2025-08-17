# Visual Enhancements Todo List

This document outlines the visual enhancements needed to make all screens consistent with the home screen's design language.

## Design Principles to Implement
1. **Gradient Backgrounds** - Use subtle gradients in headers, cards, and key UI elements
2. **Glassmorphism Effects** - Apply the `Glass` widget for containers, cards, and headers
3. **Consistent AppBar Design** - Add gradient underlines and decorative elements
4. **Enhanced Empty States** - Use glassmorphism containers with gradient accents
5. **Improved List Items** - Add gradient backgrounds and shadow effects
6. **Consistent Typography** - Use the same font weights and styling
7. **Unified Spacing** - Apply consistent padding and margins

## Screens to Enhance (Priority Order)

### 1. Archive Screen (`lib/screens/archive_screen.dart`)
- [x] Wrap header in `Glass` widget
- [x] Apply gradient background to list items (already partially implemented)
- [x] Use consistent border radius (`AppTheme.radiusL`)
- [x] Add glassmorphism effect to empty state

### 2. Trash Screen (`lib/screens/trash_screen.dart`)
- [x] Wrap header in `Glass` widget
- [x] Apply gradient background to list items
- [x] Use consistent border radius (`AppTheme.radiusL`)
- [x] Add glassmorphism effect to empty state

### 3. Folder Screen (`lib/screens/folder_screen.dart`)
- [x] Add gradient header with folder title
- [x] Apply gradient backgrounds to note list items
- [x] Use `NoteListItem` component from home screen
- [x] Add glassmorphism effect to empty state

### 4. Tags Screen (`lib/screens/tags_screen.dart`)
- [x] Add gradient header
- [x] Enhance `TagChip` with glassmorphism effects
- [x] Add glassmorphism background to screen
- [x] Add glassmorphism effect to empty state

### 5. Notes By Tag Screen (`lib/screens/notes_by_tag_screen.dart`)
- [x] Add gradient header with tag title
- [x] Apply gradient backgrounds to note list items
- [x] Use `NoteListItem` component from home screen
- [x] Add glassmorphism effect to empty state

### 6. Account/Settings Screen (`lib/screens/account_screen.dart`)
- [x] Add gradient header
- [x] Apply glassmorphism to `AccountListTile` components
- [ ] Add visual enhancements to switches and dropdowns

### 7. Theme Screen (`lib/screens/theme_screen.dart`)
- [x] Add gradient header
- [x] Apply glassmorphism to list items
- [x] Enhance font selection UI

### 8. Sync Screen (`lib/screens/sync_screen.dart`)
- [x] Add gradient header
- [x] Apply glassmorphism to status card
- [x] Enhance buttons with consistent styling

### 9. Todo Screen (`lib/screens/todo_screen.dart`)
- [x] Add gradient header
- [x] Apply glassmorphism to filter dropdown
- [x] Enhance `TodoItem` with gradient backgrounds
- [x] Improve empty state with glassmorphism

### 10. Notes Screen (`lib/screens/notes_screen.dart`)
- [x] Add gradient header with search bar
- [x] Apply glassmorphism to search bar
- [x] Enhance list/grid view with gradient backgrounds
- [x] Improve sort/filter popup menu
- [x] Add glassmorphism effect to empty state

### 11. Create Note Screen (`lib/screens/create_note_screen.dart`)
- [x] Add gradient header with back button
- [x] Apply glassmorphism to input fields
- [x] Enhance action buttons with consistent styling
- [x] Apply glassmorphism to bottom sheet

### 12. Drawing Screen (`lib/screens/drawing_screen.dart`)
- [x] Add gradient header
- [ ] Apply glassmorphism to toolbar buttons

## Components to Enhance

### Shared Components
- [x] `EmptyStateWidget` - Already has glassmorphism container
- [x] `AccountListTile` - Add gradient backgrounds on hover/tap
- [x] `TagChip` - Enhance with more visual effects

### Custom Widgets
- [x] `NoteCard` - Apply gradient backgrounds and glassmorphism
- [x] `TodoItem` - Add gradient backgrounds and visual enhancements
- [x] `NoteListItem` - Already has glassmorphism effects

## Implementation Steps

1. Start with the Archive and Trash screens as they share similar structures
2. Enhance shared components first (`EmptyStateWidget`, `TagChip`)
3. Move to list-based screens (Folder, Tags, Notes By Tag)
4. Enhance settings and utility screens (Account, Theme, Sync)
5. Finish with specialized screens (Todo, Drawing, Create Note)

## Files to Import
Ensure all screens import the necessary components:
```dart
import 'package:pinpoint/design/app_theme.dart';
```