import SwiftUI
import AppKit
import ApplicationServices

@main
struct CopyM8App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) { }
        }
    }
}

class CopyM8Window: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: CopyM8Window!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request Accessibility permission — required for System Events to paste into other apps.
        requestAccessibilityPermission()
        
        let contentView = ContentView()
        
        // Start with the pill size
        window = CopyM8Window(
            contentRect: NSRect(x: 0, y: 0, width: 28, height: 72),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.isMovableByWindowBackground = false
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView = hostingView
        
        window.orderFront(nil)
        
        // Position on the right edge
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.maxX - 28
            let y = screenRect.minY + (screenRect.height - 72) / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
    
    func applicationWillResignActive(_ notification: Notification) {
        let maxBackups = UserDefaults.standard.integer(forKey: "maxBackupsCount")
        if maxBackups > 0 {
            // Note: In AppDelegate, we don't have direct access to ClipboardManager's history.
            // Let's use NotificationCenter to tell ClipboardManager to trigger a backup.
            NotificationCenter.default.post(name: NSNotification.Name("TriggerBackup"), object: nil)
        }
    }
    
    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            print("[CopyM8] Accessibility access not granted — paste via System Events will not work.")
        }
    }
}
