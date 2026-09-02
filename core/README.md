# CopyM8 Core

Welcome to the `core` directory of CopyM8. 

Because CopyM8 requires highly platform-specific APIs (such as `AccessibilityService` on Android and `NSPasteboard` / `CGEvent` on macOS), sharing actual compiled code across platforms is impractical. 

Instead, this `core` directory serves as the ultimate **Source of Truth** for the project. It houses:
1. **Design & Architecture Documentation**
2. **Cloud Sync Schemas** (`SYNC_SCHEMA.md`) - The exact JSON structures required for macOS and Android to talk to each other via iCloud/Google Drive.
3. **Shared Assets** (Icons, color palettes, UX flows)

All platform-specific code should remain strictly isolated within its respective folder under `../platforms/`.
