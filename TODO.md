# Pinpoint TODO

A living checklist derived from the current codebase and `features.md`.

## Completed

Core Notes & Types
- Create, edit, save notes with rich text (Quill)
- Standard text notes (title + content)
- Audio notes (record, attach, play)
- To-do lists with add/edit/delete and mark complete
- Notes with reminder fields

Organization
- Create and manage folders
- Assign notes to one or more folders
- Dedicated Folder view (list notes by folder)
- Recent notes on Home

Note State & Discovery
- Pin/unpin notes
- Archive/unarchive notes
- Soft delete (Trash), restore, and permanent delete
- Search notes by title/content (Home top search bar)

Attachments & Media
- Attach images to notes
- Prompt to perform OCR on attached images (flow present)

UI/UX
- Light and dark mode
- Customizable color scheme (FlexColorScheme)
- High refresh rate support
- Home screen with folders + recent notes
- Grid/list note cards with badges and actions
- Empty states for search, archive, trash, empty folder
- Modern navigation (go_router)
- **Complete visual overhaul with glassmorphism effects and gradient backgrounds**
- **Enhanced note creation UI/UX with improved todo functionality**

Architecture & Data
- Local database (Drift + SQLite)
- Services for notes/folders, DI via get_it
- Encryption of note content at rest (EncryptionService)
- Local preferences (shared_preferences)
- Local notifications scheduled/cancelled for reminders

## Planned / To Do

High Priority
1) Biometric app lock — DONE
   - Implemented settings action and cold-start gate (Android/iOS platform config applied).

2) Tags end‑to‑end — DONE
   - Implemented UI to browse/filter by tags and manage tags on notes.

3) OCR implementation — DONE
   - Implemented OCRService using google_mlkit_text_recognition.
   - Inserted recognized text at cursor in editor with user confirmation.

4) Reminder reliability & UX — DONE
   - Initialized NotificationService on app start and ensured timezone configuration.
   - Allowed easy edit/remove of reminders from note view.

Medium Priority
5) Real voice transcription — DONE
   - Replaced placeholder with on-device transcription using speech_to_text.
   - Updated UI and error handling; inserts transcription into note.

6) Customizable Home screen — DONE
   - Implemented settings for list vs grid, and sorting.
   - Persisted and applied preferences.

7) Editor enhancements — DONE
   - Added code blocks with syntax highlighting to the Quill editor.

8) Sharing and export — DONE
   - Implemented sharing notes as text, HTML, and PDF via platform share sheets.
   - Implemented export/import of single-note backups.
   
9) Themes & fonts — DONE
   - Implemented UI to pick from more FlexColorScheme presets.
   - Implemented Google Fonts selection.
   - Optional accent color picker.

10) Drawing/sketching — DONE
    - Integrated a canvas for drawing; drawings are saved as attachments.

11) **Cloud sync UI — DONE**
    - Implemented sync manager and settings UI
    - Added sync screen with status and controls

12) **Bottom navigation enhancement — DONE**
    - Replaced third-party bottom bar with custom Material Design implementation

13) **Visual enhancements — DONE**
    - Complete visual overhaul with glassmorphism effects across all screens
    - Unified design language with gradients, consistent styling, and enhanced components

14) **Note creation overhaul — DONE**
    - Redesigned note creation UI/UX
    - Fixed todo note creation issues
    - Improved save workflow and validation

Future / Large Scope
15) Cloud sync backend
    - Optional multi-device sync (Firebase/Supabase/custom backend)
    - Conflict resolution, offline-first, encryption considerations

Quality, Security, Performance
16) Tests & CI
    - Unit/widget tests for services and UI flows; Drift query tests
    - Lint/type checks and CI pipeline

17) Security hardening
    - Secure key management for EncryptionService (secure storage, per-install key)
    - Avoid logging sensitive content

18) Performance
    - Indexes for search; assess large lists (pagination/virtualization)
    - Cache thumbnails; handle large attachments robustly

---
Notes
- Many "Next Steps" from features.md (pin, search, archive, trash, folder view, notifications, to-do interactions, grid, empty states) are already implemented.
- Partials: tags, OCR, biometrics, transcription, theme customization.
- Recently completed major enhancements: visual overhaul, note creation improvements, cloud sync UI, bottom navigation enhancement.