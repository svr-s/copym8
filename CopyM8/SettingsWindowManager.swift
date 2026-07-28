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
        
        if let mainWindow = NSApp.windows.first(where: { $0 is CopyM8Window }), let screen = mainWindow.screen {
            let mainFrame = mainWindow.frame
            let screenRect = screen.visibleFrame
            let settingsFrame = window.frame
            
            var x = mainFrame.midX - (settingsFrame.width / 2)
            // Constrain X so it doesn't bleed off the screen
            if x + settingsFrame.width > screenRect.maxX {
                x = screenRect.maxX - settingsFrame.width - 12
            }
            if x < screenRect.minX {
                x = screenRect.minX + 12
            }
            
            // Position it 55 points below the top edge of the main window to ensure the CopyM8 heading is fully visible
            var y = mainFrame.maxY - settingsFrame.height - 55
            // Constrain Y as well just in case
            if y < screenRect.minY {
                y = screenRect.minY + 12
            }
            
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
