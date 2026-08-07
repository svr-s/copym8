# CopyM8: Design Philosophy & Product Architecture

## 1. Product Vision & Philosophy
CopyM8 is designed to be the ultimate, frictionless clipboard manager for macOS. The core philosophy is to provide **infinite recall without cognitive load**. It should feel like an organic extension of macOS—always there when you need it, and instantly vanishing when you don't. It balances powerful organizational tools with a minimalist, keyboard-driven interface.

### The Intangibles
* **Fluid Invisibility:** The application serves as a pop-over overlay rather than a heavy desktop window. It aggressively auto-minimizes when focus is lost, ensuring a distraction-free environment.
* **Keyboard-First Workflow:** Power users shouldn't have to reach for a mouse. Every core action—from navigating lists, switching tabs, bulk-editing, and assigning groups, to pasting—can be performed entirely via intuitive keyboard shortcuts (`Cmd + E`, `Option + Tab`, Arrow Keys). Users can also define up to **10 custom global launch shortcuts** mapped directly to specific tabs or folders, which automatically focus the interface for rapid single-keystroke pasting.
* **Native Aesthetic:** By leveraging SwiftUI's `VisualEffectView` and ultra-thin materials, CopyM8 blends perfectly into the user's workspace, maintaining Apple's standard translucency and depth. The Settings UI is modularly segmented for a deeply native macOS feel.
* **Privacy by Default:** An explicit application blacklist (e.g., 1Password, Bitwarden) and transient data ignoring ensures sensitive information is never accidentally logged.

## 2. Core Tangibles & Functional Pillars

### A. Intelligent Categorization
The clipboard history is automatically parsed and categorized upon entry:
* **Types:** Text, Links, Images, and Files are distinctly separated.
* **Smart Deduplication:** When a user copies an identical item, CopyM8 seamlessly extracts the original item, updates its timestamp, and bounces it to the top of the history queue—fully preserving any original pinned states, custom folders, and rich formatting without cluttering the database.
* **Groups & Folders:** Users can manually assign items to custom folders for long-term project organization.
* **Pinning:** Critical snippets can be pinned to prevent them from being caught in the eviction cycle.

### B. Seamless Multi-Device Sync
CopyM8 utilizes cloud-provider-agnostic synchronization (iCloud, Dropbox, Google Drive, OneDrive). 
* **Silent Handoff:** It creates either a hidden (`.copym8_data`) or visible folder in the chosen provider to securely sync encrypted snippets across Macs.
* **Local vs. Cloud States:** Device source indicators allow users to see exactly which Mac generated a clipboard item, preventing confusion in cross-device workflows.

### C. Resource-Conscious Storage (Eviction Engine)
To maintain peak performance, the `HistoryEvictionService` constantly manages the local database footprint based on user-defined bounds:
* **Item Count & Size:** Enforces limits on the total number of items, individual item size, and total storage weight (in MB).
* **Time-to-Live (TTL):** Automatically purges unpinned items older than a specific threshold (e.g., 7 days).

## 3. UI/UX Design System

* **Typography & Sizing:** Relies heavily on system fonts (San Francisco) sized between `10pt` to `12pt`. Density is favored over whitespace to display maximum history without scrolling.
* **Component Radii:** A consistent `cornerRadius` of `8` to `10` points is used across popups, pills, and segmented controls for a softer, modern edge.
* **Spacing:** Strict modular scale (`4`, `8`, `12` padding) keeps lists compact but legible.
* **Focus Engine:** The app explicitly commands input focus. Custom keystroke handlers (`addLocalMonitorForEvents`) intercept native macOS Tab/Arrow traversal, ensuring input fields (like the Search Bar) aren't accidentally hijacked by macOS Full Keyboard Access. Unhandled keys are gracefully swallowed to prevent system "funk" warning beeps. Additionally, state-driven lockouts completely disable peripheral UI elements (Tabs, Search, Settings, Trash) during sensitive operations like Reorder Mode to maintain unwavering focus and prevent destructive misclicks. Secondary menus and toolbars utilize simplified layouts with compact "ghost" hover buttons incorporating inline shortcut badges, driving a minimalist and keyboard-centric philosophy without mouse hover tooltips.
