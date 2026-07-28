import SwiftUI
import AppKit

class SettingsWindowManager {
    static let shared = SettingsWindowManager()
    private var settingsWindow: NSWindow?
    private var eventMonitor: Any?
    
    var isSettingsOpen: Bool {
        return settingsWindow != nil && settingsWindow!.isVisible
    }
    
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
        
        if let mainWindow = NSApp.windows.first(where: { $0 is CopyM8Window }) {
            let mainFrame = mainWindow.frame
            let x = mainFrame.midX - (380 / 2)
            // Position it 40 points below the top edge of the main window to clear the CopyM8 heading
            let y = mainFrame.maxY - 440 - 40
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }
        
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: settingsView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        self.settingsWindow = window
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 && window.isKeyWindow { // ESC key
                self?.closeSettings()
                return nil
            }
            return event
        }
        
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            self?.cleanup()
        }
    }
    
    func closeSettings() {
        settingsWindow?.close()
        cleanup()
    }
    
    private func cleanup() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        settingsWindow = nil
    }
}
