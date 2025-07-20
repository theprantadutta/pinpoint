# Pinpoint Features

This document outlines the features of the Pinpoint note-taking application, including implemented features, the next set of features to be implemented, and potential bonus features for future consideration.

## Implemented Features

These features are already implemented in the application.

- **Core Note Taking:**
  - [x] Create, edit, and save notes.
  - [x] Rich text editor for formatting notes (bold, italics, etc.) using Quill.
  - [x] Support for different note types:
    - [x] Standard text notes (title and content).
    - [x] Audio notes (record and attach audio).
    - [x] To-do lists within a note.
    - [x] Notes with reminders.
- **Organization:**
  - [x] Create and manage note folders.
  - [x] Assign notes to one or more folders.
  - [x] View recent notes on the home screen.
- **Attachments:**
  - [x] Attach files to notes (e.g., images).
- **User Interface & Experience:**
  - [x] Light and dark mode support.
  - [x] Customizable color schemes using FlexColorScheme.
  - [x] Smooth performance with high refresh rate support.
  - [x] A dedicated home screen to access recent notes and folders.
  - [x] Modern navigation using `go_router`.
- **Architecture & Backend:**
  - [x] All data is stored locally in a robust SQLite database using `drift`.
  - [x] Clean architecture with a service layer for business logic.
  - [x] Efficient data fetching and caching with `fquery`.
  - [x] Dependency injection using `get_it` for a well-organized codebase.
  - [x] User preferences (like theme) are saved locally using `shared_preferences`.

## Next Steps (Core Features)

These are the recommended next features to implement to round out the core functionality of the app.

- **Note Management:**
  - [ ] **Pinning Notes:** Allow users to pin important notes to the top of the list. The `isPinned` field already exists in the database schema.
  - [ ] **Search Functionality:** Implement a global search to find notes by title or content.
  - [ ] **Archiving Notes:** Allow users to archive notes instead of deleting them permanently.
  - [ ] **Soft Deletion (Trash):** Move deleted notes to a "Trash" folder with the option to restore or permanently delete them.
- **Folder Management:**
  - [ ] **Dedicated Folder View:** A screen that shows all notes within a specific folder.
  - [ ] **Folder CRUD:** Allow users to rename and delete folders.
- **Reminders & To-dos:**
  - [ ] **Notifications:** Trigger system notifications for notes with reminders.
  - [ ] **To-do List Interaction:** Mark to-do items as complete directly from the note view.
- **UI/UX Refinements:**
  - [ ] **Note Grid View:** Display notes in a staggered grid view on the home screen for better visual organization.
  - [ ] **Empty States:** Design and implement informative empty states (e.g., when there are no notes or search results).

## Bonus & Future Features

These are more advanced features that could be considered for future versions of the app.

- **Collaboration & Sync:**
  - [ ] **Cloud Sync:** Sync notes across multiple devices using a cloud service (e.g., Firebase, Supabase, or a custom backend).
  - [ ] **Note Sharing:** Share notes with other users for viewing or collaboration.
- **Advanced Editor Features:**
  - [ ] **Markdown Support:** Allow users to write notes in Markdown.
  - [ ] **Code Blocks:** Add support for syntax-highlighted code blocks in the editor.
  - [ ] **Drawing/Sketching:** Integrate a canvas for drawing or handwriting notes.
- **Security:**
  - [ ] **Biometric Lock:** Protect the app with biometric authentication (fingerprint/face ID). The `isBiometricEnabled` flag is already in the code.
  - [ ] **Note Encryption:** Encrypt the content of notes for enhanced privacy.
- **Automation & Integration:**
  - [ ] **Tags:** Add tags to notes for more flexible organization.
  - [ ] **Optical Character Recognition (OCR):** Extract text from images attached to notes.
  - [ ] **Voice Transcription:** Transcribe audio notes into text automatically.
- **Customization:**
  - [ ] **Customizable Home Screen:** Allow users to customize the layout of the home screen.
  - [ ] **More Themes:** Add a wider variety of themes and fonts.
