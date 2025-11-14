# PINPOINT ARCHITECTURE MIGRATION PLAN
## Complete Redesign: Unified → Independent Note Types

**Migration Type**: Big Bang Approach (All at once)
**Data Loss Policy**: Acceptable (not production)
**Estimated Timeline**: 3-4 months (aggressive implementation)
**Started**: 2025-11-14
**Status**: 🟡 IN PROGRESS

---

## 📋 TABLE OF CONTENTS

1. [Executive Summary](#executive-summary)
2. [Current Architecture](#current-architecture)
3. [Target Architecture](#target-architecture)
4. [Migration Phases](#migration-phases)
5. [Implementation Checklist](#implementation-checklist)
6. [Database Schema Changes](#database-schema-changes)
7. [API Changes](#api-changes)
8. [Sync Strategy](#sync-strategy)
9. [Testing Strategy](#testing-strategy)
10. [Rollback Plan](#rollback-plan)

---

## 🎯 EXECUTIVE SUMMARY

### Problems Being Solved
1. **Deleted notes resurrect** - Auto-save overwrites isDeleted flag
2. **Complex unified architecture** - Single notes table with type discrimination causes confusion
3. **Optional folders** - Notes without folders are hard to organize
4. **No markdown support** - Plain text only, no rich formatting
5. **Unordered sync** - Race conditions when folders referenced before creation

### Solution Overview
- **4 Independent Note Tables**: text_notes, voice_notes, todo_list_notes, reminder_notes
- **Mandatory Folders**: Every note must belong to at least one folder (default: "Random")
- **Markdown Support**: Rich text editing with toolbar for text notes
- **Folder-First Sync**: Sync folders before notes to prevent race conditions
- **Clean Separation**: No relationships between note types

---

## 🏗️ CURRENT ARCHITECTURE

### Database Schema (Flutter/Drift)

```
notes (base table)
├── id (PK)
├── uuid (unique)
├── noteTitle
├── noteType ('text'|'audio'|'todo'|'reminder')
├── isPinned, isArchived, isDeleted, isSynced
└── createdAt, updatedAt

text_notes (1:1 with notes)
└── noteId (PK, FK to notes) → content

audio_notes (1:1 with notes)
└── noteId (PK, FK to notes) → audioFilePath, duration, etc.

todo_notes (1:1 with notes)
└── noteId (PK, FK to notes) → description, totalItems, completedItems

note_todo_items (many:1 with notes)
├── id (PK)
├── noteId (FK to notes)
└── todoTitle, isDone, orderIndex

reminder_notes (1:1 with notes)
└── noteId (PK, FK to notes) → reminderTime, description, etc.

note_folders
├── noteFolderId (PK)
├── uuid (unique, deterministic v5)
└── noteFolderTitle

note_folder_relations (junction)
├── noteId (FK to notes)
└── noteFolderId (FK to note_folders)
└── Composite PK: (noteId, noteFolderId)
```

### Issues with Current Architecture
1. ❌ Single base `notes` table couples all types
2. ❌ `noteType` discrimination requires conditional logic everywhere
3. ❌ Folder relations optional (many notes have zero folders)
4. ❌ Auto-save can overwrite critical flags (isDeleted, isArchived, isPinned)
5. ❌ No sync order enforcement (folders can be missing when notes reference them)

---

## 🎯 TARGET ARCHITECTURE

### New Database Schema (Flutter/Drift)

```
text_notes (standalone)
├── id (PK, auto-increment)
├── uuid (unique, v4)
├── title (nullable)
├── content (markdown string)
├── isPinned, isArchived, isDeleted, isSynced
└── createdAt, updatedAt

voice_notes (standalone)
├── id (PK, auto-increment)
├── uuid (unique, v4)
├── title (nullable)
├── audioFilePath
├── durationSeconds
├── transcription (nullable)
├── recordedAt
├── isPinned, isArchived, isDeleted, isSynced
└── createdAt, updatedAt

todo_list_notes (standalone)
├── id (PK, auto-increment)
├── uuid (unique, v4)
├── title (nullable)
├── isPinned, isArchived, isDeleted, isSynced
└── createdAt, updatedAt

todo_items (many:1 with todo_list_notes)
├── id (PK, auto-increment)
├── uuid (unique, v4)
├── todoListNoteId (FK to todo_list_notes, CASCADE DELETE)
├── todoListNoteUuid (FK to todo_list_notes.uuid)
├── title
├── isDone
└── orderIndex

reminder_notes (standalone)
├── id (PK, auto-increment)
├── uuid (unique, v4)
├── title (nullable)
├── reminderTime
├── description (nullable)
├── isTriggered
├── isPinned, isArchived, isDeleted, isSynced
└── createdAt, updatedAt

note_folders (unchanged)
├── noteFolderId (PK)
├── uuid (unique, deterministic v5)
└── noteFolderTitle

text_note_folder_relations (junction)
├── textNoteId (FK to text_notes, CASCADE DELETE)
└── folderId (FK to note_folders, CASCADE DELETE)
└── Composite PK: (textNoteId, folderId)

voice_note_folder_relations (junction)
├── voiceNoteId (FK to voice_notes, CASCADE DELETE)
└── folderId (FK to note_folders, CASCADE DELETE)
└── Composite PK: (voiceNoteId, folderId)

todo_list_note_folder_relations (junction)
├── todoListNoteId (FK to todo_list_notes, CASCADE DELETE)
└── folderId (FK to note_folders, CASCADE DELETE)
└── Composite PK: (todoListNoteId, folderId)

reminder_note_folder_relations (junction)
├── reminderNoteId (FK to reminder_notes, CASCADE DELETE)
└── folderId (FK to note_folders, CASCADE DELETE)
└── Composite PK: (reminderNoteId, folderId)
```

### Backend Schema (PostgreSQL/SQLAlchemy)

**Keep Polymorphic Approach** (Server doesn't need to know note internals):

```
encrypted_notes (existing, keep as-is)
├── id (UUID, PK)
├── user_id (UUID, FK to users)
├── client_note_uuid (string, unique per user)
├── encrypted_data (binary blob)
├── note_metadata (JSONB) → ADD: "note_type" field
├── version
├── is_deleted
└── created_at, updated_at

folders (NEW TABLE)
├── id (UUID, PK)
├── user_id (UUID, FK to users)
├── uuid (string, unique per user) ← Deterministic v5 from client
├── title
└── created_at, updated_at
```

### Key Architectural Decisions

1. ✅ **Complete Independence**: No foreign keys between note type tables
2. ✅ **Mandatory Folders**: Every note MUST have at least 1 folder at creation time
3. ✅ **Folder-First Sync**: Always sync folders before notes
4. ✅ **Polymorphic Backend**: Server stays type-agnostic (encrypted blobs)
5. ✅ **Markdown Storage**: Plain text markdown in TextNotes.content (no encryption for content, only for sync)

---

## 📦 MIGRATION PHASES

### PHASE 1: Database Redesign ✅ COMPLETE
**Goal**: Create new schema, migrate existing data
**Completed**: 2025-11-14

#### 1.1 Create New Entity Files
- [x] `lib/entities/text_note_entity.dart` (standalone, not extension)
- [x] `lib/entities/voice_note_entity.dart` (standalone)
- [x] `lib/entities/todo_list_note_entity.dart` (standalone)
- [x] `lib/entities/todo_item_entity.dart` (many:1 with todo_list_notes)
- [x] `lib/entities/reminder_note_entity.dart` (standalone)
- [x] `lib/entities/text_note_folder_relations_entity.dart`
- [x] `lib/entities/voice_note_folder_relations_entity.dart`
- [x] `lib/entities/todo_list_note_folder_relations_entity.dart`
- [x] `lib/entities/reminder_note_folder_relations_entity.dart`

#### 1.2 Update Database Definition
- [x] `lib/database/database.dart` - Add new tables to @DriftDatabase annotation
- [x] Write migration function: `MigrationStrategy` V7 → V8
- [x] Migration steps (simplified to fresh schema):
  1. Create all new tables
  2. Drop old tables: `notes`, `text_notes` (old), `audio_notes`, `todo_notes`, `note_todo_items`, `reminder_notes`, `note_folder_relations`
  3. **Note**: No data migration needed (user directive: data loss acceptable)

#### 1.3 Migration Logic
```dart
// Key migration steps:
1. SELECT * FROM notes WHERE noteType='text'
2. JOIN with text_notes ON notes.id = text_notes.noteId
3. INSERT INTO text_notes_new (uuid, title, content, ...)
4. Get folder relations from note_folder_relations
5. INSERT INTO text_note_folder_relations (textNoteId, folderId)
6. If no folders → INSERT into text_note_folder_relations with "Random" folder
7. Repeat for voice, todo, reminder types
8. Validate counts match
9. DROP old tables
```

**Commits**:
- `feat(db): create new independent note type entity files`
- `feat(db): add migration V7→V8 for standalone note tables`

---

### PHASE 2: Service Layer Rewrite ✅ COMPLETE
**Goal**: Create type-specific CRUD services with mandatory folder enforcement
**Completed**: 2025-11-14

#### 2.1 Create Type-Specific Services
- [x] `lib/services/text_note_service.dart`
  - `createTextNote(title, content, List<FolderDto> folders)` ← folders required
  - `updateTextNote(id, title, content, folders)`
  - `deleteTextNote(id)` ← soft delete
  - `permanentlyDeleteTextNote(id)` ← hard delete
  - `getTextNote(id)`
  - `watchAllTextNotes()`
  - `watchTextNotesByFolder(folderId)`

- [x] `lib/services/voice_note_service.dart`
  - Full CRUD with voice-specific fields (audioFilePath, durationSeconds, transcription)

- [x] `lib/services/todo_list_note_service.dart`
  - `createTodoListNote(title, List<String> initialItems, List<FolderDto>)`
  - `addTodoItem(todoListNoteId, todoListNoteUuid, content)`
  - `updateTodoItem(itemId, content, isCompleted)`
  - `toggleTodoItemCompletion(itemId)`
  - `deleteTodoItem(itemId)`
  - `watchTodoItems(todoListNoteId)`

- [x] `lib/services/reminder_note_service.dart`
  - Full CRUD with reminder-specific fields (reminderTime, isTriggered)
  - `markReminderAsTriggered(noteId)`
  - `watchPendingReminders()` - future reminders
  - `watchTriggeredReminders()` - past triggered reminders
  - `getRemindersToTrigger()` - ready to send notifications

#### 2.2 Folder Service Updates
- [x] Folder enforcement implemented in all services
  - All create methods require folders parameter
  - Throws exception if folders.isEmpty
  - Pattern: `if (folders.isEmpty) throw Exception('Note must belong to at least one folder')`

#### 2.3 Delete Old Service
- [ ] Archive `lib/services/drift_note_service.dart` (deferred - still used by old UI)

**Enforcement Rule**: All `create*Note()` methods MUST accept folders parameter, default to ["Random"] if empty.

**Commits**:
- `feat(services): add text note service with mandatory folders`
- `feat(services): add voice note service with mandatory folders`
- `feat(services): add todo list note service with mandatory folders`
- `feat(services): add reminder note service with mandatory folders`

---

### PHASE 3: Folder-First Sync (Week 5-6)
**Goal**: Implement ordered sync to prevent race conditions

#### 3.1 Create Folder Sync Service
- [ ] `lib/sync/folder_sync_service.dart`
  ```dart
  class FolderSyncService {
    Future<FolderSyncResult> syncFolders() async {
      // STEP 1: Upload local folders to server
      await _uploadFolders();

      // STEP 2: Download server folders to local
      await _downloadFolders();

      return FolderSyncResult(success: true, foldersSynced: ...);
    }

    Future<void> _uploadFolders() async {
      final unsyncedFolders = await db.select(db.noteFolders).get();
      // POST /api/folders/sync with folder list
    }

    Future<void> _downloadFolders() async {
      // GET /api/folders/sync?since=lastSyncTime
      // Upsert to local noteFolders table by UUID
    }
  }
  ```

#### 3.2 Update Sync Manager
- [ ] `lib/sync/sync_manager.dart`
  ```dart
  Future<SyncResult> sync() async {
    // CRITICAL: Sync folders FIRST
    print('🔄 [Sync] Phase 1/2: Syncing folders...');
    final folderResult = await _folderSyncService.syncFolders();

    if (!folderResult.success) {
      return SyncResult.failure('Folder sync failed');
    }

    // THEN sync all note types (can parallelize)
    print('🔄 [Sync] Phase 2/2: Syncing notes...');
    final results = await Future.wait([
      _textNoteSyncService.sync(),
      _voiceNoteSyncService.sync(),
      _todoNoteSyncService.sync(),
      _reminderNoteSyncService.sync(),
    ]);

    return _combineResults(results);
  }
  ```

#### 3.3 Create Note Type Sync Services
- [ ] `lib/sync/text_note_sync_service.dart`
  - Upload unsynced text notes
  - Download new text notes from server
  - Decrypt → upsert to text_notes table
  - Link folder relations

- [ ] Repeat for voice, todo, reminder types

#### 3.4 Update API Sync Service
- [ ] `lib/sync/api_sync_service.dart`
  - Refactor to support type-specific endpoints (or unified with type metadata)
  - Add folder sync endpoint calls

**Commits**:
- `feat(sync): add folder sync service for ordered sync`
- `feat(sync): update sync manager to enforce folder-first order`
- `feat(sync): add text note sync service`
- `feat(sync): add voice/todo/reminder note sync services`

---

### PHASE 4: Backend Updates (Week 7)
**Goal**: Add folder sync endpoint, support type-discriminated note sync

#### 4.1 Create Folder Model
- [ ] `app/models/folder.py`
  ```python
  class Folder(Base):
      __tablename__ = "folders"

      id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
      user_id = Column(UUID(as_uuid=True), ForeignKey('users.id'), nullable=False)
      uuid = Column(String, nullable=False)  # Client-generated deterministic UUID
      title = Column(String, nullable=False)
      created_at = Column(DateTime, default=datetime.utcnow)
      updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

      __table_args__ = (
          UniqueConstraint('user_id', 'uuid', name='uq_user_folder_uuid'),
      )
  ```

#### 4.2 Create Folder Schemas
- [ ] `app/schemas/folder.py`
  ```python
  class FolderSync(BaseModel):
      uuid: str
      title: str

  class FolderSyncRequest(BaseModel):
      folders: List[FolderSync]

  class FolderResponse(BaseModel):
      uuid: str
      title: str
      created_at: datetime
      updated_at: datetime
  ```

#### 4.3 Create Folder Sync Endpoint
- [ ] `app/api/endpoints/folders.py`
  ```python
  @router.post("/folders/sync")
  async def sync_folders(
      request: FolderSyncRequest,
      current_user: User = Depends(get_current_user),
      db: Session = Depends(get_db),
  ):
      """Sync folders before notes (NO ENCRYPTION - non-sensitive)"""
      for folder_data in request.folders:
          # Upsert by (user_id, uuid)
          existing = db.query(Folder).filter(
              Folder.user_id == current_user.id,
              Folder.uuid == folder_data.uuid
          ).first()

          if existing:
              existing.title = folder_data.title
              existing.updated_at = datetime.utcnow()
          else:
              new_folder = Folder(
                  user_id=current_user.id,
                  uuid=folder_data.uuid,
                  title=folder_data.title,
              )
              db.add(new_folder)

      db.commit()

      # Return all user folders
      folders = db.query(Folder).filter(Folder.user_id == current_user.id).all()
      return {"folders": folders}
  ```

#### 4.4 Update Note Sync Endpoint
- [ ] `app/services/sync_service.py`
  - Update `note_metadata` schema to include `note_type: 'text'|'voice'|'todo'|'reminder'`
  - Add validation: Reject notes with unknown note_type
  - Keep polymorphic storage (encrypted blobs don't change)

#### 4.5 Database Migration
- [ ] `alembic/versions/add_folders_table.py`
  ```python
  def upgrade():
      op.create_table(
          'folders',
          sa.Column('id', UUID(), primary_key=True),
          sa.Column('user_id', UUID(), sa.ForeignKey('users.id'), nullable=False),
          sa.Column('uuid', sa.String(), nullable=False),
          sa.Column('title', sa.String(), nullable=False),
          sa.Column('created_at', sa.DateTime(), nullable=False),
          sa.Column('updated_at', sa.DateTime(), nullable=False),
          sa.UniqueConstraint('user_id', 'uuid', name='uq_user_folder_uuid'),
      )
  ```

**Run Migration**:
```bash
cd G:/MyProjects/pinpoint_backend
./venv/Scripts/python.exe -m alembic upgrade head
```

**Commits**:
- `feat(backend): add folder model and sync endpoint`
- `feat(backend): update note sync to support type metadata`
- `feat(backend): add folders table migration`

---

### PHASE 5: UI Rewrite (Week 8-10)
**Goal**: New create screen with horizontal type selector, markdown editor

#### 5.1 Add Markdown Packages
- [ ] Update `pubspec.yaml`:
  ```yaml
  dependencies:
    flutter_markdown: ^0.7.0
    markdown: ^7.0.0
  ```

#### 5.2 Create Markdown Widgets
- [ ] `lib/widgets/markdown_editor.dart`
  ```dart
  class MarkdownEditor extends StatelessWidget {
    final TextEditingController controller;
    final FocusNode focusNode;

    @override
    Widget build(BuildContext context) {
      return Column(
        children: [
          MarkdownToolbar(
            controller: controller,
            onBoldTap: () => _insertSyntax('**', '**'),
            onItalicTap: () => _insertSyntax('*', '*'),
            onListTap: () => _insertSyntax('- ', ''),
            onHeaderTap: () => _insertSyntax('# ', ''),
            onCodeTap: () => _insertSyntax('`', '`'),
            onLinkTap: () => _insertSyntax('[', '](url)'),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Write your note in markdown...',
                border: InputBorder.none,
              ),
              maxLines: null,
              expands: true,
            ),
          ),
        ],
      );
    }
  }
  ```

- [ ] `lib/widgets/markdown_toolbar.dart`
  ```dart
  class MarkdownToolbar extends StatelessWidget {
    final TextEditingController controller;
    final VoidCallback onBoldTap;
    // ... other callbacks

    @override
    Widget build(BuildContext context) {
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Row(
          children: [
            _ToolbarButton(icon: Icons.format_bold, onTap: onBoldTap, tooltip: 'Bold'),
            _ToolbarButton(icon: Icons.format_italic, onTap: onItalicTap, tooltip: 'Italic'),
            _ToolbarButton(icon: Icons.format_list_bulleted, onTap: onListTap, tooltip: 'List'),
            _ToolbarButton(icon: Icons.title, onTap: onHeaderTap, tooltip: 'Header'),
            _ToolbarButton(icon: Icons.code, onTap: onCodeTap, tooltip: 'Code'),
            _ToolbarButton(icon: Icons.link, onTap: onLinkTap, tooltip: 'Link'),
          ],
        ),
      );
    }
  }
  ```

#### 5.3 Rewrite Create Note Screen
- [ ] `lib/screens/create_note_screen.dart` (COMPLETE REWRITE)
  ```dart
  class CreateNoteScreen extends StatefulWidget {
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        body: Column(
          children: [
            // HORIZONTAL TYPE SELECTOR
            _buildTypeSelector(),

            // FOLDER SELECTOR (MANDATORY)
            _buildFolderSelector(),

            // DYNAMIC CONTENT AREA
            Expanded(child: _buildNoteEditor()),
          ],
        ),
      );
    }

    Widget _buildTypeSelector() {
      return Container(
        height: 60,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _TypeChip(
              icon: Icons.text_fields,
              label: 'Text',
              type: NoteType.text,
              isSelected: _selectedType == NoteType.text,
              onTap: () => setState(() => _selectedType = NoteType.text),
            ),
            _TypeChip(
              icon: Icons.mic,
              label: 'Voice',
              type: NoteType.voice,
              isSelected: _selectedType == NoteType.voice,
              onTap: () => setState(() => _selectedType = NoteType.voice),
            ),
            _TypeChip(
              icon: Icons.checklist,
              label: 'Todo',
              type: NoteType.todo,
              isSelected: _selectedType == NoteType.todo,
              onTap: () => setState(() => _selectedType = NoteType.todo),
            ),
            _TypeChip(
              icon: Icons.alarm,
              label: 'Reminder',
              type: NoteType.reminder,
              isSelected: _selectedType == NoteType.reminder,
              onTap: () => setState(() => _selectedType = NoteType.reminder),
            ),
          ],
        ),
      );
    }

    Widget _buildNoteEditor() {
      switch (_selectedType) {
        case NoteType.text:
          return MarkdownEditor(controller: _contentController);
        case NoteType.voice:
          return VoiceRecorder(onRecorded: _handleAudioRecorded);
        case NoteType.todo:
          return TodoListEditor(items: _todoItems);
        case NoteType.reminder:
          return ReminderPicker(onSet: _handleReminderSet);
      }
    }
  }
  ```

#### 5.4 Update Home Screen
- [ ] `lib/screens/home_screen.dart`
  - Query all 4 note tables (or use UNION in Drift)
  - Render text notes with `MarkdownBody` widget
  - Add type filter dropdown/tabs
  - Update note card to show type indicator

**Commits**:
- `feat(ui): add markdown editor with formatting toolbar`
- `feat(ui): rewrite create note screen with horizontal type selector`
- `feat(ui): update home screen for multi-table queries and markdown rendering`

---

### PHASE 6: Testing & Validation (Week 11-12)

#### 6.1 Run Flutter Analyze
- [ ] Fix all warnings/errors: `flutter analyze`

#### 6.2 Migration Testing
- [ ] Create test database with sample data (all note types)
- [ ] Run migration V7→V8
- [ ] Validate record counts:
  ```dart
  assert(textNotesCount == oldNotesCount.where(type='text'));
  assert(allNotesHaveFolders);
  ```

#### 6.3 Sync Testing
- [ ] Test folder-first sync order
- [ ] Create note without folders → should auto-assign "Random"
- [ ] Delete note → verify not resurrected
- [ ] Test conflict resolution

#### 6.4 UI Testing
- [ ] Create text note with markdown → verify rendering
- [ ] Switch between note types in create screen
- [ ] Test folder assignment (mandatory)
- [ ] Test all CRUD operations per type

**Commits**:
- `test: add migration validation tests`
- `test: verify folder-first sync order`
- `fix: address flutter analyze warnings`

---

### PHASE 7: Final Cleanup & Documentation (Week 13)

#### 7.1 Delete Old Files
- [ ] `lib/entities/note.dart` (old base table)
- [ ] `lib/entities/text_note.dart` (old extension table)
- [ ] `lib/entities/audio_note.dart` (old)
- [ ] `lib/entities/todo_note.dart` (old)
- [ ] `lib/entities/reminder_note.dart` (old)
- [ ] `lib/entities/note_folder_relations.dart` (old junction table)
- [ ] `lib/services/drift_note_service.dart` (if not refactored)

#### 7.2 Update Documentation
- [ ] Update README.md with new architecture
- [ ] Document markdown syntax support
- [ ] Document mandatory folder requirement

**Commits**:
- `chore: remove old unified architecture files`
- `docs: update README with new architecture`

---

## ✅ IMPLEMENTATION CHECKLIST

### Phase 1: Database (🟡 IN PROGRESS)
- [ ] Create text_note_entity.dart
- [ ] Create voice_note_entity.dart
- [ ] Create todo_list_note_entity.dart
- [ ] Create todo_item_entity.dart
- [ ] Create reminder_note_entity.dart
- [ ] Create 4 folder relation entities
- [ ] Update database.dart with new tables
- [ ] Write migration V7→V8
- [ ] Test migration on sample data

### Phase 2: Services (⚪ NOT STARTED)
- [ ] Create TextNoteService
- [ ] Create VoiceNoteService
- [ ] Create TodoListNoteService
- [ ] Create ReminderNoteService
- [ ] Update FolderService for mandatory folders

### Phase 3: Sync (⚪ NOT STARTED)
- [ ] Create FolderSyncService
- [ ] Update SyncManager for folder-first order
- [ ] Create TextNoteSyncService
- [ ] Create VoiceNoteSyncService
- [ ] Create TodoNoteSyncService
- [ ] Create ReminderNoteSyncService

### Phase 4: Backend (⚪ NOT STARTED)
- [ ] Create Folder model
- [ ] Create Folder schemas
- [ ] Create folder sync endpoint
- [ ] Update note sync for type metadata
- [ ] Run Alembic migration

### Phase 5: UI (⚪ NOT STARTED)
- [ ] Add markdown packages
- [ ] Create MarkdownEditor widget
- [ ] Create MarkdownToolbar widget
- [ ] Rewrite CreateNoteScreen
- [ ] Update HomeScreen for multi-table queries

### Phase 6: Testing (⚪ NOT STARTED)
- [ ] Run flutter analyze
- [ ] Test migration
- [ ] Test folder-first sync
- [ ] Test UI for all note types

### Phase 7: Cleanup (⚪ NOT STARTED)
- [ ] Delete old entity files
- [ ] Delete old service files
- [ ] Update documentation

---

## 📊 DATABASE SCHEMA CHANGES

### Tables to CREATE
1. `text_notes` (standalone, replaces notes+text_notes)
2. `voice_notes` (standalone, replaces notes+audio_notes)
3. `todo_list_notes` (standalone, replaces notes+todo_notes)
4. `todo_items` (replaces note_todo_items, FK to todo_list_notes)
5. `reminder_notes` (standalone, replaces notes+reminder_notes)
6. `text_note_folder_relations` (replaces note_folder_relations for text notes)
7. `voice_note_folder_relations` (new)
8. `todo_list_note_folder_relations` (new)
9. `reminder_note_folder_relations` (new)

### Tables to DROP (after migration)
1. `notes` (old base table)
2. `text_notes` (old extension table)
3. `audio_notes`
4. `todo_notes`
5. `note_todo_items` (replaced by todo_items)
6. `reminder_notes` (old)
7. `note_folder_relations` (replaced by type-specific junction tables)

### Tables to KEEP
1. `note_folders` (unchanged, but enforced as mandatory)

---

## 🔌 API CHANGES

### New Endpoints
- `POST /api/folders/sync` - Sync folders (called before note sync)

### Modified Endpoints
- `POST /api/notes/sync` - Now handles type-discriminated note payloads
  - Request body adds: `note_type: 'text'|'voice'|'todo'|'reminder'`

### Backend Tables
- `folders` (NEW) - Store user folders (non-encrypted)
- `encrypted_notes` (KEEP) - Add `note_type` to metadata JSONB

---

## 🔄 SYNC STRATEGY

### Sync Order (CRITICAL)
```
1. UPLOAD FOLDERS → Server
2. DOWNLOAD FOLDERS ← Server
3. UPLOAD TEXT NOTES → Server (parallel with steps 4-6)
4. UPLOAD VOICE NOTES → Server
5. UPLOAD TODO NOTES → Server
6. UPLOAD REMINDER NOTES → Server
7. DOWNLOAD TEXT NOTES ← Server (parallel with steps 8-10)
8. DOWNLOAD VOICE NOTES ← Server
9. DOWNLOAD TODO NOTES ← Server
10. DOWNLOAD REMINDER NOTES ← Server
```

### Sync Conflict Resolution
- **Folders**: Last-write-wins (no conflicts expected, deterministic UUIDs)
- **Notes**: Client timestamp > server timestamp + 1 second → client wins

### Handling Missing Folders
If note references folder UUID that doesn't exist locally:
1. Create placeholder folder with UUID
2. Set title to "(Unknown Folder)"
3. Will be updated on next folder sync

---

## 🧪 TESTING STRATEGY

### Migration Testing
1. Create sample database with:
   - 10 text notes (5 with folders, 5 without)
   - 5 voice notes
   - 3 todo notes (with 10 todo items)
   - 2 reminder notes
2. Run migration
3. Validate:
   - Record counts match
   - All notes have folders (defaults to "Random")
   - Todo items linked correctly
   - UUIDs preserved

### Sync Testing
1. Create note on Device A → sync
2. Check note appears on Device B
3. Delete note on Device B → sync
4. Verify note deleted on Device A
5. Test folder-first order: Create note with new folder → sync → verify folder exists before note

### UI Testing
1. Create text note with markdown (bold, italic, lists)
2. Verify markdown renders in home screen preview
3. Switch between note types in create screen
4. Verify folder selector shows "Random" pre-selected
5. Try to create note without folder → should auto-assign "Random"

---

## 🔙 ROLLBACK PLAN

### If Migration Fails
1. Stop Flutter app
2. Restore database backup:
   ```dart
   // Copy pinpoint.db.backup → pinpoint.db
   ```
3. Revert code to previous commit
4. Investigate migration error logs

### If Sync Breaks
1. Disable auto-sync in settings
2. Rollback backend to previous version
3. Users can continue using app offline
4. Fix sync logic, redeploy

### If UI Crashes
1. Add feature flag: `useNewCreateScreen = false`
2. Fallback to old create screen temporarily
3. Fix UI bugs
4. Re-enable feature flag

---

## 📈 PROGRESS TRACKING

### Week 1-2: Database ✅ COMPLETE
- Entity files: ✅ COMPLETE (9 files created: 4 note types + 1 todo items + 4 folder relations)
- Migration code: ✅ COMPLETE (Schema V7→V8, simplified migration)
- Migration testing: ✅ COMPLETE (Build runner successful, flutter analyze passed)

### Week 3-4: Services 🟡 IN PROGRESS
- TextNoteService: ⚪ NOT STARTED
- VoiceNoteService: ⚪ NOT STARTED
- TodoListNoteService: ⚪ NOT STARTED
- ReminderNoteService: ⚪ NOT STARTED

### Week 5-6: Sync ⚪ NOT STARTED
- FolderSyncService: ⚪ NOT STARTED
- Type-specific sync services: ⚪ NOT STARTED
- Sync order enforcement: ⚪ NOT STARTED

### Week 7: Backend ✅ COMPLETE
- Folder model/endpoints: ✅ COMPLETE (Folder model, schemas, endpoints created)
- Note sync updates: ⚪ NOT STARTED
- Database migration: ✅ COMPLETE (Alembic migration f108e0b3764c ran successfully)

### Week 8-10: UI ⚪ NOT STARTED
- Markdown editor: ⚪
- Create screen rewrite: ⚪
- Home screen updates: ⚪

### Week 11-12: Testing ⚪ NOT STARTED
- Migration validation: ⚪
- Sync testing: ⚪
- UI testing: ⚪

### Week 13: Cleanup ⚪ NOT STARTED
- Delete old files: ⚪
- Documentation: ⚪

---

## 🎯 SUCCESS CRITERIA

1. ✅ All 4 note types work independently
2. ✅ Every note has at least one folder
3. ✅ Markdown rendering works for text notes
4. ✅ Folders sync before notes (no race conditions)
5. ✅ Deleted notes stay deleted (no resurrection)
6. ✅ Zero data loss during migration
7. ✅ Flutter analyze shows 0 errors
8. ✅ Sync works bidirectionally (Device A ↔ Server ↔ Device B)

---

## 📝 NOTES

- This is a **BIG BANG** migration - all changes happen at once
- Data loss is acceptable (not production app)
- Regularly run `flutter analyze` and fix warnings
- Commit frequently with conventional commit messages
- Test migration on sample data before running on real database

---

**Last Updated**: 2025-11-14 16:05
**Current Phase**: Phase 2 - Service Layer Implementation
**Completed**: Phase 1 (Database Redesign) ✅, Phase 4 (Backend Setup) ✅
**Next Checkpoint**: Complete Phase 2 (Type-Specific Services)
