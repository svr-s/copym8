# CopyM8 Code Architecture & Structure

This document provides a high-level overview of the physical code architecture for the `copym8-macos` app. The codebase is heavily modularized using Swift extensions to keep core classes manageable while maintaining a single source of truth for state.

## 1. Application Core & Lifecycle
- **`CopyM8App.swift`**: The main entry point. Bootstraps the application, registers background services, configures the menu bar item, and manages the lifecycle of the global pop-over window.
- **`ContentView.swift`**: The root view of the main interface. Handles the primary layout (Header, Search, Tabs, List, Footer).
- **`ContentViewModel.swift`**: The UI state layer. Bridges the gap between the `ClipboardManager` data and the `ContentView`, handling UI-specific states (e.g., active tab, search query, selection index).

## 2. The Brain: `ClipboardManager`
`ClipboardManager.swift` is the central nervous system of the app. Because it handles a massive amount of logic, it is cleanly broken down into domain-specific extensions:
- **`ClipboardManager+Polling.swift`**: Hooks into the macOS `NSPasteboard` to listen for new copy events and parse data (Text, Images, Files).
- **`ClipboardManager+Items.swift`**: Core CRUD operations for individual clipboard items (creating, deleting, pinning, deduplicating).
- **`ClipboardManager+Folders.swift`**: Logic for assigning items to custom folders and managing group states.
- **`ClipboardManager+Queue.swift`**: Handles the Sequential Paste (Queue Mode) logic, maintaining the `queueIDs` buffer and the `queuePlayheadIndex`.
- **`ClipboardManager+Reordering.swift`**: Logic for manually reordering pinned items or queue items.
- **`ClipboardManager+Sync.swift`**: Hooks into the `CloudSyncService` to broadcast local changes or consume remote changes.

## 3. Services & Background Managers
These are isolated, single-responsibility singletons or injected services that handle specific background tasks:
- **`StorageService.swift`**: The local persistence layer. Handles writing clipboard history and metadata to disk efficiently.
- **`HistoryEvictionService.swift`**: The garbage collector. Runs periodically to enforce user limits (max items, max size, TTL) and purge old unpinned data.
- **`CloudSyncService.swift`**: The synchronization engine. Monitors and writes to the `.copym8_data` folder in the user's iCloud/Dropbox for seamless multi-device handoff.
- **`BackupManager.swift`**: Handles scheduled or manual backups of the user's clipboard history.
- **`ShortcutManager.swift`**: Registers global macOS keyboard shortcuts (using libraries like MASShortcut or native Carbon APIs) and routes them to app actions (e.g., global launch, queue paste).
- **`SettingsWindowManager.swift`**: Manages the distinct `NSWindow` for preferences, ensuring it behaves like a standard macOS settings panel.

## 4. UI Components & Modifiers
The `Views/` directory contains highly reusable SwiftUI components:
- **`Components/`**:
  - `SearchBarView`, `TabBarView`, `HeaderView`: The top-level navigation components.
  - `ClipboardListView`, `ClipboardItemView`, `EmptyStateView`: The core rendering engine for the history list.
  - `KeyboardMonitorModifier.swift`: A custom SwiftUI modifier that intercepts global keystrokes (`NSEvent`) to ensure the "Keyboard First" philosophy works flawlessly without macOS hijacking the focus.
- **`Settings/`**:
  - `SettingsView.swift` and the `Tabs/` directory (General, Sync, Privacy, Types, Shortcuts) modularize the complex preferences window.
- **`VisualEffectView.swift`**: An `NSViewRepresentable` wrapper around `NSVisualEffectView` to provide the native macOS translucent blur behind the app.
- **`QueueHUDView.swift`**: The standalone Heads-Up Display that appears globally when Queue Mode is actively recording.

## 5. UI Extensions
To prevent `ContentView.swift` from becoming bloated, its logic is also split into extensions:
- **`ContentView+Window.swift`**: Handles logic for the pop-over appearance, sizing, and edge-snapping.
- **`ContentView+Keyboard.swift` / `+Actions.swift`**: Handles internal keyboard shortcuts (up/down arrows for navigation, Enter to paste, etc.) and routes them to the ViewModel.
