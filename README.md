# CopyM8 ♾️

CopyM8 is a modern, buttery-smooth, and lightweight clipboard manager built natively for macOS. It acts as an infinitely expanding memory bank for your clipboard, tucked away beautifully on the edge of your screen. 

## ✨ Features

- **Magnetic Docking**: Drag the window and it snaps flawlessly to the left, right, or top edges of your screen using zero-lag, native AppKit window tracking.
- **Edge Hover**: When snapped to an edge, CopyM8 collapses into an unobtrusive, beautifully glowing pill. Simply move your mouse to the edge of the screen to expand it.
- **Global Hotkeys**: Use the keyboard to rapidly open your history, navigate, and paste without ever taking your hands off the keys.
- **Auto-Pasting**: Select any item from your history and CopyM8 will instantly switch back to your previous application and automatically inject the text.
- **Dynamic Adaptive Layouts**: Resize the window horizontally or vertically and the UI gracefully adapts. Choose between *Dense* and *Spaced* layouts to fit your workflow.
- **Customizable Themes**: Quickly personalize the glowing aesthetic with 9 distinct color palettes ranging from Glacier and Neon to sleek Monochrome options.
- **Native macOS Feel**: Built by carefully bridging the ultra-modern aesthetics of SwiftUI with the raw, uncompromising performance of native AppKit APIs.

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
