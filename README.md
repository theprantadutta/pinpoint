# 📍 Pinpoint

<div align="center">

**A beautiful, privacy-focused note-taking app built with Flutter**

[![Flutter](https://img.shields.io/badge/Flutter-3.6.0+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[Features](#-features) • [Screenshots](#-screenshots) • [Tech Stack](#-tech-stack) • [Getting Started](#-getting-started) • [Architecture](#-architecture)

</div>

---

## 🎯 Overview

Pinpoint is a feature-rich, privacy-first note-taking application that combines beautiful design with powerful functionality. Built with Flutter and Material Design 3, it offers a seamless experience across all platforms with end-to-end encryption, multiple note types, and advanced organization features.

### Why Pinpoint?

- 🔐 **Privacy First**: End-to-end AES-256 encryption with biometric authentication
- 🎨 **Beautiful Design**: Glassmorphism UI with smooth animations and Material 3
- 📝 **Versatile**: Multiple note types - text, audio, todo lists, and reminders
- 🗂️ **Organized**: Hierarchical folders, tags, pinning, and powerful search
- 🌙 **Dark First**: Gorgeous dark mode with 5 accent color themes
- ⚡ **Fast**: Optimized performance with high refresh rate support
- 🔄 **Sync Ready**: Built-in cloud sync infrastructure

---

## ✨ Features

### 📝 Note Types

- **Title & Content** - Rich text notes with formatting
- **Audio Recording** - Voice notes with playback controls
- **Todo Lists** - Interactive checklists with real-time auto-save
- **Reminders** - Time-based notifications with timezone support

### 🗂️ Organization

- **Folders** - Hierarchical organization with many-to-many relationships
- **Pinning** - Keep important notes at the top
- **Archive** - Store completed or old notes
- **Trash** - Soft delete with restore functionality
- **Search** - Global search across titles and content
- **Sorting** - By date modified, created, or title

### 🔒 Security & Privacy

- **Biometric Lock** - Fingerprint/Face ID authentication
- **End-to-End Encryption** - AES-256 encryption for note content
- **Secure Storage** - Device-specific key management
- **Privacy Focus** - No analytics, no tracking

### 🎨 Design & Customization

- **Glassmorphism** - Beautiful frosted glass effects throughout
- **Material 3** - Modern Material Design language
- **5 Accent Colors** - Mint, Iris, Rose, Amber, Ocean
- **Dark & Light Themes** - Fully themed with high contrast mode
- **High Refresh Rate** - Smooth 120Hz+ support
- **Custom Typography** - 8 Google Fonts to choose from
- **Pill-Shaped Design** - Consistent rounded corners across the app

### 🚀 Advanced Features

- **OCR** - Extract text from images using Google ML Kit
- **Voice Transcription** - Speech-to-text for quick note creation
- **Drawing Canvas** - Sketch and draw within notes
- **Attachments** - Add images and files to notes
- **Export** - Share notes as text, HTML, or PDF
- **Import/Export** - Backup and restore your notes

---

## 📸 Screenshots

<!-- Screenshot placeholders - Add your screenshots here -->

### Home & Notes

| Home Screen | Notes List | Search |
|------------|------------|---------|
| ![Home](docs/screenshots/home.png) | ![Notes](docs/screenshots/notes.png) | ![Search](docs/screenshots/search.png) |
| *Main dashboard with folders and recent notes* | *All notes with sorting and filtering* | *Powerful search functionality* |

### Note Creation

| Text Note | Todo List | Audio Note |
|-----------|-----------|------------|
| ![Text](docs/screenshots/text-note.png) | ![Todo](docs/screenshots/todo-note.png) | ![Audio](docs/screenshots/audio-note.png) |
| *Rich text editor with formatting* | *Interactive checklist with auto-save* | *Voice recording with playback* |

### Organization

| Folders | Todo Overview | Archive |
|---------|--------------|---------|
| ![Folders](docs/screenshots/folders.png) | ![Todos](docs/screenshots/todos.png) | ![Archive](docs/screenshots/archive.png) |
| *Organize notes into folders* | *All todos across all notes* | *Completed and archived notes* |

### Customization

| Theme Selection | Dark Mode | Light Mode |
|----------------|-----------|------------|
| ![Themes](docs/screenshots/themes.png) | ![Dark](docs/screenshots/dark-mode.png) | ![Light](docs/screenshots/light-mode.png) |
| *Choose your accent color* | *Beautiful dark theme* | *Clean light theme* |

### Security

| Biometric Lock | Encryption | Settings |
|---------------|------------|----------|
| ![Biometric](docs/screenshots/biometric.png) | ![Encryption](docs/screenshots/encryption.png) | ![Settings](docs/screenshots/settings.png) |
| *Secure app with fingerprint/face* | *End-to-end encrypted notes* | *Comprehensive settings* |

---

## 🛠️ Tech Stack

### Framework & Language
- **Flutter** 3.6.0+ - Cross-platform UI framework
- **Dart** - Modern programming language
- **Material 3** - Latest Material Design

### Database & Storage
- **Drift** 2.24.0 - Type-safe SQLite database with reactive queries
- **Shared Preferences** - Persistent key-value storage
- **Flutter Secure Storage** - Encrypted credential storage
- **Path Provider** - Cross-platform file system paths

### Security & Authentication
- **Local Auth** - Biometric authentication (fingerprint/face)
- **Encrypt** - AES-256 encryption
- **Flutter Secure Storage** - Secure key management

### UI/UX Libraries
- **Google Fonts** - Custom typography
- **Animate Do** + **Flutter Animate** - Smooth animations
- **Staggered Grid View** - Masonry layouts
- **Skeletonizer** - Loading states
- **Toastification** - User feedback

### Media & Input
- **Record** + **Audioplayers** - Audio recording and playback
- **Image Picker** - Image selection from gallery/camera
- **Google ML Kit** - OCR text recognition
- **Speech to Text** - Voice transcription
- **Painter** - Drawing canvas

### Navigation & State
- **Go Router** 17.0.0 - Declarative routing
- **Get It** 9.0.5 - Dependency injection
- **Provider** - State management where needed

### Notifications
- **Flutter Local Notifications** - Cross-platform notifications
- **Timezone** - Timezone-aware scheduling

### Export & Sharing
- **Share Plus** - Native share functionality
- **Printing** + **PDF** - PDF generation and export
- **File Picker** - File selection dialogs

### Development Tools
- **Drift Dev** + **Build Runner** - Code generation
- **Logger** - Structured logging
- **Drift DB Viewer** - Database inspection

---

## 🏗️ Architecture

### Clean Architecture with Service Layer

```
lib/
├── screens/              # UI screens (11 main screens)
│   ├── home_screen.dart
│   ├── notes_screen.dart
│   ├── todo_screen.dart
│   ├── create_note_screen.dart
│   └── ...
├── components/           # Reusable UI components
│   ├── home_screen/
│   ├── create_note_screen/
│   └── shared/
├── services/            # Business logic layer
│   ├── drift_note_service.dart
│   ├── drift_note_folder_service.dart
│   ├── encryption_service.dart
│   ├── auth_service.dart
│   └── ...
├── database/            # Data persistence
│   └── database.dart
├── entities/            # Database table definitions
│   ├── note.dart
│   ├── note_folder.dart
│   └── ...
├── models/              # Data transfer objects
│   ├── note_with_details.dart
│   └── ...
├── design_system/       # Complete design system
│   ├── colors.dart
│   ├── typography.dart
│   ├── gradients.dart
│   ├── elevations.dart
│   ├── theme.dart
│   └── components/
├── navigation/          # Routing configuration
│   └── app_navigation.dart
├── sync/               # Cloud sync infrastructure
│   └── sync_manager.dart
└── util/               # Utilities and helpers
```

### Key Patterns

- **Service Layer Pattern** - Business logic in static service classes
- **Repository Pattern** - Services abstract database operations
- **Stream-based Reactivity** - Drift watches for real-time updates
- **DTO Pattern** - Separate models for data transfer
- **Dependency Injection** - GetIt service locator
- **Clean Architecture** - Clear separation of concerns

### Database Schema (v4)

```sql
tables:
  - notes (id, title, content, type, encryption, timestamps)
  - note_folders (id, title)
  - note_folder_relations (note_id, folder_id) -- many-to-many
  - note_todo_items (id, note_id, title, is_done)
  - note_attachments (id, note_id, file_path, type)
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.6.0 or higher
- Dart SDK 3.0 or higher
- Android Studio / Xcode (for mobile)
- VS Code or Android Studio (recommended)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/theprantadutta/pinpoint.git
   cd pinpoint
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate code** (Drift database)
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

### Platform-Specific Setup

#### Android
- Minimum SDK: 24
- Target SDK: 36
- Permissions configured in `AndroidManifest.xml`

#### iOS
- iOS 12.0+
- Permissions configured in `Info.plist`
- Biometric authentication setup required

---

## 🎨 Design System

### Color Themes

Choose from 5 beautiful accent colors:

- **Neon Mint** (default) - `#10B981`
- **Purple Dream** - `#6366F1`
- **Pink Bliss** - `#F43F5E`
- **Orange Sunset** - `#F59E0B`
- **Blue Ocean** - `#0EA5E9`

### Typography

8 Google Fonts available:
- Inter (default)
- Roboto
- Open Sans
- Lato
- Montserrat
- Poppins
- Source Sans Pro
- Noto Sans

### Design Principles

- **Glassmorphism** - Frosted glass effects with backdrop blur
- **Consistent Spacing** - 8px grid system
- **Pill-Shaped** - Rounded corners everywhere (24px for cards, 999px for inputs)
- **Elevation System** - 6 levels (xs, sm, md, lg, xl, xxl)
- **Smooth Animations** - 200-400ms duration with emphasized curves

---

## 📝 Recent Updates

### January 2025 - Major Design & UX Overhaul

#### Design System Enhancements
- ✨ Implemented comprehensive glassmorphism across all screens
- 🎨 Added gradient backgrounds to headers and UI elements
- 🔄 Unified design language with consistent pill-shaped components
- 🌈 Enhanced light mode with optimized shadow intensities
- 🎭 Fixed app bar theming for proper light/dark mode support

#### Note Creation System
- 🐛 Fixed critical todo note creation bug (empty list access)
- ⚡ Implemented real-time auto-save for all note types
- 🔢 Added temporary ID system for unsaved todo items
- ✅ Improved validation and error handling
- 💾 Enhanced save/discard workflow

#### Todo System Overhaul
- 📋 Redesigned todo screen with glassmorphic cards
- 🔗 Implemented navigation from todos to parent notes
- ✨ New todo card UI matching note card design
- 🎯 Fixed overflow issues with long note titles
- ⚡ Real-time todo status updates across screens

#### Theme Customization
- 🌓 Added light/dark theme toggle in settings
- 💾 Persistent theme preference using SharedPreferences
- 🎨 5 accent color themes with proper theming
- 📱 Responsive design improvements

#### Performance & Polish
- ⚡ Optimized shadow rendering for light mode (70% reduction)
- 🎭 Improved animation performance
- 📱 Better high refresh rate support
- 🔧 Code generation updates for database schema

---

## 🗺️ Roadmap

### Upcoming Features

- [ ] **Cloud Sync** - Google Drive / Dropbox integration
- [ ] **Collaboration** - Share and collaborate on notes
- [ ] **Tags System** - Multi-tag support for notes
- [ ] **Templates** - Pre-built note templates
- [ ] **Web Clipper** - Save web content directly
- [ ] **Markdown Support** - Full markdown editing
- [ ] **Kanban Board** - Visual task management
- [ ] **Calendar View** - Timeline and calendar integration
- [ ] **Widgets** - Home screen widgets
- [ ] **Desktop Apps** - Native Windows, macOS, Linux builds

### Testing & Quality

- [ ] Unit tests for services
- [ ] Widget tests for UI components
- [ ] Integration tests for user flows
- [ ] CI/CD pipeline setup
- [ ] Automated releases

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Material Design team for the design guidelines
- All open-source package contributors
- The Flutter community

---

## 📧 Contact

**Project Link:** [https://github.com/theprantadutta/pinpoint](https://github.com/theprantadutta/pinpoint)

---

<div align="center">

Made with ❤️ using Flutter

**⭐ Star this repo if you find it useful!**

</div>
