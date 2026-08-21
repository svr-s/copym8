# CopyM8 ♾️

CopyM8 is a modern, buttery-smooth, and lightweight clipboard manager built natively for macOS. It acts as an infinitely expanding memory bank for your clipboard, tucked away beautifully on the edge of your screen. 

## ✨ Features

- **Magnetic Docking**: Drag the window and it snaps flawlessly to the left, right, or top edges of your screen using zero-lag, native AppKit window tracking.
- **Edge Hover**: When snapped to an edge, CopyM8 collapses into an unobtrusive, beautifully glowing pill. Simply move your mouse to the edge of the screen to expand it.
- **Dynamic Adaptive Layouts & Resizing**: Resize the window horizontally or vertically and the UI gracefully adapts. Press `Cmd + L` to instantly toggle between *Dense* and *Spaced* layouts.
- **Smart Categorization (Tabs)**: Your clipboard history is beautifully organized into 8 primary tabs: *Queue*, *All*, *Pinned*, *Groups*, *Text*, *Links*, *Images*, and *Files*, followed by up to 3 Custom App-specific tabs. Use `Option + 1-0` (and `Option + Q` or ``Option + ` `` for Queue) to instantly switch between them!
- **Ultra-Low Memory Footprint**: Thanks to a highly optimized file-backed architecture, all heavy clipboard data (high-res images, massive rich text blocks, and file payloads) is instantly offloaded to secure local disk storage. This keeps CopyM8's RAM consumption virtually flat—whether you have 15 items or 2,500 items, the app stays lightning-fast and feather-light.
- **Image & File Support**: Natively extracts copied images and data into local storage and reads raw `.fileURL` references directly from macOS Finder and IDEs without duplicating the actual files. Features a unified, dynamically truncated UI for images and files, including automatic smart rounding for file sizes.
- **Intelligent Storage Management**: Protect your disk space by setting maximum limits (e.g., max item size of 20MB, total storage cap of 100MB). Limits are strictly checked per payload chunk (so copying 6 5MB files is just copying tiny text paths, while copying a single 30MB image chunk gets safely rejected). CopyM8 automatically enforces the total storage cap by evicting the oldest unpinned items. **Curated Data Protection:** Any item you explicitly Pin, assign to a Folder, or manually Reorder is completely immune to automatic background eviction. Your curated data will never be deleted to enforce a megabyte limit, ensuring your organized work is perfectly safe!
- **Rich & Plain Paste**: Press `Enter` (or `1-0`) or `Left Click` to strip formatting and paste plain text, hold `Cmd` while clicking or pressing Enter to inject exact Rich Text formats with styles intact, or hold `Option` while clicking (or `Cmd + Control + Enter` on keyboard) to paste Rich Text with all hyperlinks cleanly stripped out. 
- **Context Capture**: Captures the source application (e.g., Safari, Xcode) and exact timestamp of every copy.
- **Live Search & Re-indexing**: Search by text *or* source application. Includes a streamlined search bar UI with integrated clear functionality. The `1-0` quick-paste keyboard shortcuts dynamically re-index to map perfectly to your filtered search results.
- **Sequential Paste (Queue Mode)**: Map global shortcuts to record a sequence of copies, and systematically paste them out one by one across any application without ever opening the UI! Inside the Queue tab, track your position with the visual playhead indicator and instantly snap the playhead to any item using `Cmd + Enter` or `Cmd + Click`.
- **Pinning**: Press `Cmd + P` or right-click to pin items to save them forever. In Edit Mode, press `Cmd + U` to instantly unpin selected items.
- **Grouping**: Press `Cmd + G` to assign items to custom folders. When the assignment pop-up is open, type the folder's shortcut alphabet (A, B, C...) to assign it instantly, or navigate using Arrow Keys. *(Note: The system Restored folder is safely excluded from manual assignment).* Press `Cmd + U` in the Groups tab to ungroup.
- **Full Keyboard Navigation**: Never touch the mouse. Use Arrow keys to navigate, `Cmd + E` to toggle Edit mode, `Spacebar` to select items, `Opt + Tab` and `Opt + Shift + Tab` to cycle through tabs, and `Enter` to paste.
- **Accordion Folder Groups**: Use `Right Arrow` to expand folders and view their items. Use `Left Arrow` to collapse or jump to the parent folder. Use `Option + Left Arrow` for a quick "Super Collapse" to instantly shut a folder and return to its header. Press `Option + R` when a folder is highlighted to seamlessly rename it in-line! You can also use `Cmd + Shift + Down` to instantly expand all folders, and `Cmd + Shift + Up` to collapse them all.
- **Advanced Bulk Edit Mode**: Press `Cmd + E` to enter a Finder-style selection mode. Layout shifts (like expanding folders for Edit Mode) intelligently preserve your exact selection index and gracefully re-center your focus with a buttery smooth spring animation. Use `Shift + Up/Down` to highlight a range of items, and hit `Space` to bulk toggle checkboxes! Features context-aware "Select All" (`Cmd + A`) that perfectly respects your active filters. If your selection includes a mix of folders and items, actions like Grouping and Pinning are intelligently applied only to the valid entries within your selection, safely skipping folders while preserving Bulk Delete. All footer actions utilize compact ghost buttons with inline shortcuts (`⌘I` for Import, `⌘G` for Group) to minimize mouse dependency.
- **Soft Delete & Trash Bin**: Safely remove items without annoying confirmation popups by sending them to a dedicated Trash Bin using `Backspace` (or `Cmd + Backspace` to permanently delete). You can effortlessly restore items (`Cmd + Z`) directly from the Trash tab (`Cmd + Shift + T`), which automatically deduplicates and bounces the restored item back to the top of your active history while retaining its original pinned state or grouping! Features compact inline shortcut buttons for quick actions (`Restore ⌘Z`, `Delete ⌘⌫`, and `Empty ⇧⌘⌫`).
- **Strict Reorder Mode**: Enter dedicated Reorder Mode to seamlessly reorder items (or whole folders!) using `Cmd + Up/Down`. Reordering intelligently scopes to your active search filters or specific folder contents. You can also freeze specific items at the top while sorting using the `Freeze Top ⌃F` shortcut field! To maintain focus and prevent accidental changes during rapid reordering, mouse interactions and peripheral controls (like Tabs, Search, Settings, and Trash) are intentionally locked out. The streamlined footer removes unnecessary buttons (like Cancel) to maximize layout breathing room.
- **Cloud Sync & Cross-Device Import**: Keep your clipboard synchronized across multiple Macs using any cloud folder (iCloud, Dropbox, Google Drive). CopyM8 intelligently detects other devices on the same sync network and allows you to seamlessly view remote clipboards (with safe, read-only guardrails). Features a unified **Cloud Copy** system that natively syncs Text, Images, and Files across devices using an atomic FIFO eviction logic based on your custom storage configurations. You can natively browse folders on remote devices as if they were local! Press `Cmd + I` to effortlessly import remote items directly into your local machine, featuring smart deduplication that progressively enhances local metadata and skips existing Cloud Copy entries without duplicating items! Press `Cmd + Shift + D` to open the custom Device Switcher pop-up.
- **Privacy & Security Filters**: Take complete control over what gets saved. CopyM8 actively listens for `ConcealedType` metadata from 1Password, Keychain, and Safari to silently ignore and protect your passwords. Dive into the Privacy Settings to toggle ignore filters for transient macro data, or even block Universal Clipboard handoffs from your iPhone.
- **Modular Settings & Custom Launch Shortcuts**: The Settings window is cleanly segmented (General, Types, Sync, Privacy, Shortcuts). You can configure up to **10 custom global launch shortcuts**! Map them directly to your favorite tabs, or even drill down and assign a global shortcut to open CopyM8 directly into a specific custom folder with the search ready—so pasting from a specific folder is just a single keystroke away.
- **Smart Deduplication & Themes**: Copying a duplicate item instantly updates its timestamp, bouncing it right back to the top of your queue while beautifully preserving its original formatting, Pinned status, and Group assignments! Personalize the glowing aesthetic directly from Settings, set unpinned clipboard limits (up to 1,000 items), enforce maximum storage caps, and monitor real-time Storage Statistics (Total Items, Pinned Items, Memory Usage).

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
