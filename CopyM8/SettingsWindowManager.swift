import SwiftUI
import AppKit

class SettingsWindowManager {
    static let shared = SettingsWindowManager()
    private var settingsWindow: NSWindow?
    
    func showSettings(draftHistoryCount: Binding<Int>, maxHistoryCount: Binding<Int>, clipboard: ClipboardManager, shortcut: ShortcutManager) {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsView(draftHistoryCount: draftHistoryCount, maxHistoryCount: maxHistoryCount)
            .environmentObject(clipboard)
            .environmentObject(shortcut)
            
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CopyM8 Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: settingsView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        self.settingsWindow = window
    }
}
