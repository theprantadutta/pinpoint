# WYSIWYG Markdown Editor Migration Guide

This guide contains all the remaining changes needed to complete the WYSIWYG markdown editor implementation using AppFlowy Editor.

## ✅ Completed Steps

1. ✅ Added `appflowy_editor: ^6.1.0` and `markdown: ^7.2.2` to `pubspec.yaml`
2. ✅ Downgraded `device_info_plus` to `^11.5.0` for compatibility
3. ✅ Created `lib/utils/markdown_converter.dart` with markdown ↔ Document conversion functions
4. ✅ Updated `lib/widgets/markdown_editor.dart` to use AppFlowy Editor instead of TextField
5. ✅ Updated `lib/widgets/markdown_toolbar.dart` with formatting buttons for AppFlowy Editor

## 📝 Remaining Steps

### Step 1: Add AppFlowy Editor Localization to MaterialApp

**File:** `lib/main.dart`

**Add import at the top:**
```dart
import 'package:appflowy_editor/appflowy_editor.dart';
```

**Update localizationsDelegates (around line 413):**
```dart
localizationsDelegates: const [
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  AppFlowyEditorLocalizations.delegate,  // ← ADD THIS LINE
],
```

---

### Step 2: Update CreateNoteScreenV2 to use AppFlowy Editor

**File:** `lib/screens/create_note_screen_v2.dart`

#### 2a. Add import at the top:
```dart
import 'package:appflowy_editor/appflowy_editor.dart';
```

#### 2b. Replace Text Content Controller with EditorState (around line 52-53):

**REMOVE:**
```dart
late TextEditingController _textContentController;
late FocusNode _textContentFocusNode;
```

**REPLACE WITH:**
```dart
late EditorState _editorState;
late FocusNode _textContentFocusNode;
```

#### 2c. Update initState() (around line 79-93):

**REMOVE:**
```dart
_textContentController = TextEditingController();
_textContentFocusNode = FocusNode();
```

**REPLACE WITH:**
```dart
_editorState = EditorState.blank();
_textContentFocusNode = FocusNode();
```

**REMOVE:**
```dart
_textContentController.addListener(_scheduleAutoSave);
```

**ADD (after _titleController.addListener):**
```dart
_editorState.transactionStream.listen((_) => _scheduleAutoSave());
```

#### 2d. Update dispose() (around line 97-106):

**REMOVE:**
```dart
_textContentController.dispose();
```

**ADD:**
```dart
_editorState.dispose();
```

#### 2e. Update _autoSaveNote() method (around line 289):

**CHANGE:**
```dart
final content = _textContentController.text.trim();
```

**TO:**
```dart
final content = MarkdownEditor.editorStateToMarkdown(_editorState).trim();
```

#### 2f. Update _buildTextNoteContent() method (around line 704-715):

**REPLACE ENTIRE METHOD:**
```dart
Widget _buildTextNoteContent() {
  return SliverFillRemaining(
    hasScrollBody: false,
    child: MarkdownEditor(
      editorState: _editorState,
      focusNode: _textContentFocusNode,
      hintText: 'Start writing your note...',
      showToolbar: true,
      onChanged: (markdown) {
        // Optional: handle changes if needed
        debugPrint('📝 Content changed: ${markdown.length} chars');
      },
    ),
  );
}
```

#### 2g. Update _saveNote() method - find where it saves text content:

**FIND the section that creates/updates text notes (likely around line 140-200):**

**CHANGE:**
```dart
content: _textContentController.text.trim(),
```

**TO:**
```dart
content: MarkdownEditor.editorStateToMarkdown(_editorState).trim(),
```

#### 2h. Update note loading (if you have an edit mode):

**If there's a method that loads existing notes, ADD:**
```dart
_editorState = MarkdownEditor.createEditorStateFromMarkdown(note.content ?? '');
```

---

### Step 3: (Optional) Add Formatted Previews in Note Lists

**File:** `lib/components/home_screen/note_types/title_content_type.dart`

This step is optional but recommended for better UX. You can use `flutter_markdown` to show formatted previews in the notes list instead of plain text.

**Example:**
```dart
import 'package:flutter_markdown/flutter_markdown.dart';

// In the preview section:
MarkdownBody(
  data: note.textContent?.substring(0, min(100, note.textContent?.length ?? 0)) ?? '',
  styleSheet: MarkdownStyleSheet(
    p: TextStyle(fontSize: 14, color: cs.onSurface.withOpacity(0.7)),
  ),
)
```

---

## 🧪 Testing Checklist

After making all changes:

1. ⬜ Run `flutter pub get` to ensure all packages are installed
2. ⬜ Run `flutter analyze` to check for errors
3. ⬜ Build and run the app
4. ⬜ Create a new note with formatted text (bold, italic, lists, headings)
5. ⬜ Verify formatting shows in real-time (no markdown syntax visible)
6. ⬜ Save the note and verify auto-save works
7. ⬜ Close and reopen the note - verify it loads correctly
8. ⬜ Open an existing markdown note - verify it converts properly
9. ⬜ Test toolbar buttons (bold, italic, headings, lists, etc.)
10. ⬜ Verify backwards compatibility with existing notes

---

## 🐛 Troubleshooting

### Issue: "markdownToDocument not found"
**Solution:** Ensure `import 'package:appflowy_editor/appflowy_editor.dart';` is added to the file

### Issue: "EditorScrollController required"
**Solution:** The markdown_editor.dart already creates this internally, no action needed

### Issue: "Existing notes don't load"
**Solution:** Ensure you're calling `MarkdownEditor.createEditorStateFromMarkdown()` when loading existing content

### Issue: "Build errors after changes"
**Solution:** Run `flutter clean && flutter pub get && flutter pub run build_runner build --delete-conflicting-outputs`

---

## 📚 Additional Resources

- [AppFlowy Editor Documentation](https://pub.dev/packages/appflowy_editor)
- [AppFlowy Editor GitHub](https://github.com/AppFlowy-IO/appflowy-editor)
- [AppFlowy Editor Examples](https://github.com/AppFlowy-IO/appflowy-editor/tree/main/example)

---

## 🎯 Key Benefits

After completing this migration:

- ✨ Users see formatted text while typing (WYSIWYG)
- 🎨 No visible markdown syntax (** or *)
- 📝 Rich toolbar for easy formatting
- 💾 Still stores as markdown (backward compatible)
- 🔄 Existing notes work seamlessly
- 📱 Better UX similar to Google Docs/Notion

---

**Note:** If you encounter any issues during migration, check the `lib/widgets/markdown_editor.dart` and `lib/widgets/markdown_toolbar.dart` files for reference on how to properly use the AppFlowy Editor API.
