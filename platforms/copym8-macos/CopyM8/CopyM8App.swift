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
    static private(set) var shared: AppDelegate!
    
    var window: CopyM8Window!
    var onboardingWindow: NSWindow?
    
    override init() {
        super.init()
        AppDelegate.shared = self
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "maxBackupsCount": 3
        ])
        
        let hasPermission = AppDelegate.checkAccessibilityPermission()
        ShortcutManager.initialExpand = false // Always start as pill
        setupMainWindow()
        
        if !hasPermission {
            showOnboardingWindow()
            // Hide the main window while onboarding is active
            window.orderOut(nil)
        }
    }
    
    /// Displays a standalone onboarding window centered on screen.
    func showOnboardingWindow() {
        let onboardingView = OnboardingView()
        let hosting = NSHostingView(rootView: onboardingView)
        
        let windowWidth: CGFloat = 480
        let windowHeight: CGFloat = 380
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = false
        win.contentView = hosting
        win.center()
        win.level = .floating
        
        onboardingWindow = win
        
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }
    
    func setupMainWindow() {
        let contentView = ContentView()
        
        let dockEdgeString = UserDefaults.standard.string(forKey: "dockEdge") ?? "right"
        let isTop = dockEdgeString == "top"
        let pillWidth: CGFloat = isTop ? 40 : 28
        let pillHeight: CGFloat = isTop ? 28 : 40
        
        let startWidth = pillWidth
        let startHeight = pillHeight
        
        window = CopyM8Window(
            contentRect: NSRect(x: 0, y: 0, width: startWidth, height: startHeight),
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
        
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = dockEdgeString == "left" ? screenRect.minX : screenRect.maxX - startWidth
            let y = dockEdgeString == "top" ? screenRect.maxY - startHeight : screenRect.minY + (screenRect.height - startHeight) / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
    
    func applicationWillResignActive(_ notification: Notification) {
        let maxBackups = UserDefaults.standard.integer(forKey: "maxBackupsCount")
        if maxBackups > 0 {
            NotificationCenter.default.post(name: NSNotification.Name("TriggerBackup"), object: nil)
        }
    }
    
    static func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !AppDelegate.checkAccessibilityPermission() {
            window?.makeKeyAndOrderFront(nil)
            if !ShortcutManager.initialExpand {
                ShortcutManager.initialExpand = true
                NotificationCenter.default.post(name: NSNotification.Name("ForceExpand"), object: nil)
            }
        }
        return true
    }
    
    /// Opens System Settings, closes onboarding window, and presents the pill at the right edge.
    func handleGrantPermissionAndLaunch() {
        // 1. Open System Settings Accessibility pane
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        
        // 2. Show main pill window at right edge
        if let win = window {
            win.makeKeyAndOrderFront(nil)
        }
        
        // 3. Close onboarding window
        onboardingWindow?.orderOut(nil)
        onboardingWindow = nil
    }
}
import SwiftUI

struct OnboardingView: View {
    @State private var isGrantHovered: Bool = false
    @State private var isManualHovered: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 76, height: 76)
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
            
            Text("Welcome to CopyM8")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text("CopyM8 is a keyboard-first clipboard manager.\nTo seamlessly capture your copies in the background and use global hotkeys, CopyM8 requires Accessibility permission.")
                .multilineTextAlignment(.center)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .padding(.horizontal, 30)
            
            HStack(spacing: 6) {
                Image(systemName: "command")
                    .font(.system(size: 13, weight: .semibold))
                Text("Press **Cmd + Shift + Space** anytime to open CopyM8.")
                    .font(.system(size: 13, weight: .regular))
            }
            .foregroundColor(.primary.opacity(0.85))
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
            .background(Color.primary.opacity(0.06))
            .cornerRadius(8)
            
            VStack(spacing: 14) {
                Button(action: {
                    AppDelegate.shared.handleGrantPermissionAndLaunch()
                }) {
                    Text("Grant Permission")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 40)
                        .background(isGrantHovered ? Color.accentColor.opacity(0.85) : Color.accentColor)
                        .cornerRadius(10)
                        .scaleEffect(isGrantHovered ? 1.03 : 1.0)
                        .shadow(color: Color.accentColor.opacity(isGrantHovered ? 0.6 : 0.3), radius: isGrantHovered ? 8 : 5, x: 0, y: isGrantHovered ? 4 : 3)
                        .animation(.easeInOut(duration: 0.15), value: isGrantHovered)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isGrantHovered = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                
                Button(action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("Open System Settings manually")
                        .font(.footnote)
                        .foregroundColor(isManualHovered ? .primary : .secondary)
                        .underline(isManualHovered)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isManualHovered = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .padding(.top, 4)
        }
        .frame(minWidth: 460, minHeight: 380)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow).ignoresSafeArea())
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
