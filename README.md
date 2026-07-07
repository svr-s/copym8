# CopyM8 ♾️

CopyM8 is a modern, buttery-smooth, and lightweight clipboard manager built natively for macOS. It acts as an infinitely expanding memory bank for your clipboard, tucked away beautifully on the edge of your screen. 

## ✨ Features

- **Magnetic Docking**: Drag the window and it snaps flawlessly to the left, right, or top edges of your screen using zero-lag, native AppKit window tracking.
- **Edge Hover**: When snapped to an edge, CopyM8 collapses into an unobtrusive, beautifully glowing pill. Simply move your mouse to the edge of the screen to expand it.
- **Dynamic Adaptive Layouts & Resizing**: Resize the window horizontally or vertically and the UI gracefully adapts. Press `Cmd + D` to instantly toggle between *Dense* and *Spaced* layouts.
- **Smart Categorization (Tabs)**: Your clipboard history is automatically organized into *Text*, *Links*, *Images*, and *Files*. Use `Option + 1-6` to instantly switch tabs!
- **Image & File Support**: Natively extracts copied images into local storage (with automatic disk-space pruning caps) and reads raw `.fileURL` references directly from macOS Finder and IDEs without duplicating the actual files.
- **Rich & Plain Paste**: Press `Enter` (or `1-0`) to strip formatting and paste plain text, or hold `Cmd` to inject exact Rich Text formats with styles intact. 
- **Context Capture**: Captures the source application (e.g., Safari, Xcode) and exact timestamp of every copy.
- **Live Search & Re-indexing**: Search by text *or* source application. The `1-0` quick-paste keyboard shortcuts dynamically re-index to map perfectly to your filtered search results.
- **Pinning**: Press `P` or right-click to pin items to save them forever.
- **Full Keyboard Navigation**: Never touch the mouse. Use Arrow keys to navigate, `Cmd + E` to toggle Edit mode, `Spacebar` to select items, `Opt + Tab` and `Opt + Shift + Tab` to cycle through tabs, and `Enter` to paste.
- **Advanced Bulk Edit Mode**: Press `Cmd + E` to enter a Finder-style selection mode. Use checkboxes or the spacebar to select items. Features context-aware "Select All" (`Cmd + A`) that perfectly respects your active filters, allowing you to bulk pin or bulk delete with ease.
- **Password Security**: Actively listens for `ConcealedType` metadata from 1Password, Keychain, and Safari to silently ignore and protect your passwords.
- **Customizable Themes & Settings**: Personalize the glowing aesthetic (`Cmd + K`), set unpinned clipboard limits, toggle specific data types, enforce maximum storage caps, and monitor real-time Storage Statistics (Total Items, Pinned Items, Memory Usage).


## 🚀 Getting Started

### Prerequisites
- macOS 14.0+ 
- Xcode 15.0+ (For building from source)

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/svr-s/CopyM8.git
   ```
2. Open `CopyM8.xcodeproj` in Xcode.
3. Build and Run (`Cmd + R`).

## 🛠 Tech Stack
- **UI Framework**: SwiftUI
- **Window Management & Global Events**: AppKit / Cocoa
- **State Management**: `@AppStorage` & Combine
- **Language**: Swift

## 🤝 Contributing
Feel free to open issues or submit pull requests for new features, bug fixes, or design improvements!

---
*Built to make copying and pasting feel like magic.*
