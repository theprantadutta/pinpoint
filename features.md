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
  - [x] Tag system for flexible organization.
- **Attachments:**
  - [x] Attach files to notes (e.g., images).
  - [x] Optical Character Recognition (OCR) to extract text from images.
- **User Interface & Experience:**
  - [x] Light and dark mode support.
  - [x] Customizable color schemes using FlexColorScheme.
  - [x] Smooth performance with high refresh rate support.
  - [x] A dedicated home screen to access recent notes and folders.
  - [x] Modern navigation using `go_router`.
  - [x] Comprehensive visual overhaul with glassmorphism effects and gradient backgrounds.
  - [x] Enhanced note creation UI/UX.
- **Note Management:**
  - [x] Pinning Notes: Allow users to pin important notes to the top of the list.
  - [x] Search Functionality: Implement a global search to find notes by title or content.
  - [x] Archiving Notes: Allow users to archive notes instead of deleting them permanently.
  - [x] Soft Deletion (Trash): Move deleted notes to a "Trash" folder with the option to restore or permanently delete them.
- **Folder Management:**
  - [x] Dedicated Folder View: A screen that shows all notes within a specific folder.
- **Reminders & To-dos:**
  - [x] Notifications: Trigger system notifications for notes with reminders.
  - [x] To-do List Interaction: Mark to-do items as complete directly from the note view.
- **UI/UX Refinements:**
  - [x] Note Grid View: Display notes in a staggered grid view on the home screen for better visual organization.
  - [x] Empty States: Design and implement informative empty states (e.g., when there are no notes or search results).
- **Advanced Features:**
  - [x] Voice Transcription: Transcribe audio notes into text automatically.
  - [x] Drawing/Sketching: Integrate a canvas for drawing or handwriting notes.
  - [x] Sharing and export: Share notes as text, HTML, and PDF.
  - [x] Cloud Sync UI: User interface for managing cloud synchronization.
- **Security:**
  - [x] Biometric Lock: Protect the app with biometric authentication (fingerprint/face ID).
  - [x] Note Encryption: Encrypt the content of notes for enhanced privacy.
- **Customization:**
  - [x] Customizable Home Screen: Allow users to customize the layout of the home screen.
  - [x] More Themes: Add a wider variety of themes and fonts.

## Architecture & Backend

- [x] All data is stored locally in a robust SQLite database using `drift`.
- [x] Clean architecture with a service layer for business logic.
- [x] Efficient data fetching and caching with `fquery`.
- [x] Dependency injection using `get_it` for a well-organized codebase.
- [x] User preferences (like theme) are saved locally using `shared_preferences`.

## Next Steps (Planned Features)

These are the recommended next features to implement to enhance the app further.

- **Dedicated Screens:**
  - [ ] **Notes Screen:** Dedicated view for browsing and managing all notes with powerful filtering capabilities.
  - [ ] **Todo Screen:** Unified view for managing all todo items across notes.
- **Cloud Sync Backend:**
  - [ ] **Multi-device Sync:** Implement backend for cloud synchronization across multiple devices.
  - [ ] **Conflict Resolution:** Handle sync conflicts gracefully.
- **Advanced Editor Features:**
  - [ ] **Markdown Support:** Allow users to write notes in Markdown.
  - [ ] **Code Blocks:** Enhanced syntax highlighting for code blocks.
- **Automation & Integration:**
  - [ ] **More Advanced OCR:** Improved text recognition accuracy.
  - [ ] **Voice Commands:** Voice-based note creation and management.
- **Performance & Quality:**
  - [ ] **Comprehensive Testing:** Unit and widget tests for all features.
  - [ ] **Performance Optimization:** Indexes for search and pagination for large lists.

## Future Features

These are more advanced features that could be considered for future versions of the app.

- **Collaboration & Sync:**
  - [ ] **Note Sharing:** Share notes with other users for viewing or collaboration.
  - [ ] **Real-time Collaboration:** Multiple users editing the same note simultaneously.
- **AI Integration:**
  - [ ] **Smart Organization:** AI-powered note categorization and tagging.
  - [ ] **Content Summarization:** Automatic summarization of long notes.
  - [ ] **Intelligent Search:** Natural language search capabilities.
- **Advanced Customization:**
  - [ ] **Custom Widgets:** User-created widgets for the home screen.
  - [ ] **Plugin System:** Third-party extensions and integrations.
- **Offline Capabilities:**
  - [ ] **Enhanced Offline Mode:** Better offline functionality with improved caching.