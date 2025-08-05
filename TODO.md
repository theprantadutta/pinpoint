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

2) Tags end‑to‑end
   - Ensure Drift entities/relations + CRUD fully wired (creation flow exists)
   - UI to browse/filter by tags and manage tags on notes
   - Integrate tags into search/filter chips

3) OCR implementation
   - Implement OCRService using google_mlkit_text_recognition
   - Insert recognized text at cursor in editor with user confirmation

4) Reminder reliability & UX
   - Initialize NotificationService on app start; ensure timezone configuration
   - Allow easy edit/remove of reminders from note view
   - Consider rescheduling on reboot where applicable

Medium Priority
5) Real voice transcription
   - Replace placeholder with on-device or cloud transcription
   - Progress UI and error handling; insert transcription into note

6) Customizable Home screen
   - Settings for list vs grid, density, sort (pinned/last edited), visible sections
   - Persist and apply preferences

7) Editor enhancements
   - Code blocks with syntax highlight (if not supported by Quill out-of-the-box)
   - Optional: Markdown mode or import/export to Markdown

8) Sharing and export
   - Share notes as text/HTML/Markdown/PDF via platform share sheets
   - Export/import single-note backups

9) Themes & fonts
   - UI to pick from more FlexColorScheme presets and Google Fonts
   - Optional accent color picker

Future / Large Scope
10) Cloud sync
    - Optional multi-device sync (Firebase/Supabase/custom backend)
    - Conflict resolution, offline-first, encryption considerations

11) Drawing/sketching
    - Canvas integration; save drawings as attachments/embeds

Quality, Security, Performance
12) Tests & CI
    - Unit/widget tests for services and UI flows; Drift query tests
    - Lint/type checks and CI pipeline

13) Security hardening
    - Secure key management for EncryptionService (secure storage, per-install key)
    - Avoid logging sensitive content

14) Performance
    - Indexes for search; assess large lists (pagination/virtualization)
    - Cache thumbnails; handle large attachments robustly

---
Notes
- Many “Next Steps” from features.md (pin, search, archive, trash, folder view, notifications, to-do interactions, grid, empty states) are already implemented.
- Partials: tags, OCR, biometrics, transcription, theme customization.
