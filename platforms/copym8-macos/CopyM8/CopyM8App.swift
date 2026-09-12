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
    var onboardingWindow: NSWindow?
    var accessibilityTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "maxBackupsCount": 3
        ])
        
        let hasPermission = AppDelegate.checkAccessibilityPermission()
        ShortcutManager.initialExpand = !hasPermission
        setupMainWindow()
        
        if !hasPermission {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
            startAccessibilityTimer()
        }
    }
    
    func startAccessibilityTimer() {
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            if AppDelegate.checkAccessibilityPermission() {
                DispatchQueue.main.async {
                    self?.accessibilityTimer?.invalidate()
                    self?.accessibilityTimer = nil
                    
                    NSApp.activate(ignoringOtherApps: true)
                    self?.window?.makeKeyAndOrderFront(nil)
                    NotificationCenter.default.post(name: NSNotification.Name("PermissionGranted"), object: nil)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        accessibilityTimer = timer
    }
    
    func setupMainWindow() {
        let contentView = ContentView()
        
        let dockEdgeString = UserDefaults.standard.string(forKey: "dockEdge") ?? "right"
        let isTop = dockEdgeString == "top"
        let pillWidth: CGFloat = isTop ? 40 : 28
        let pillHeight: CGFloat = isTop ? 28 : 40
        
        let hasPermission = AppDelegate.checkAccessibilityPermission()
        
        var startWidth = ShortcutManager.initialExpand ? CGFloat(UserDefaults.standard.double(forKey: "windowWidth")) : pillWidth
        var startHeight = ShortcutManager.initialExpand ? CGFloat(UserDefaults.standard.double(forKey: "windowHeight")) : pillHeight
        
        if startWidth == 0 { startWidth = 320 }
        if startHeight == 0 { startHeight = 420 }
        
        if !hasPermission {
            startWidth = max(450, startWidth)
            startHeight = max(350, startHeight)
        }
        
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
            let x: CGFloat
            let y: CGFloat
            if !hasPermission {
                // Center on screen for onboarding
                x = screenRect.minX + (screenRect.width - startWidth) / 2
                y = screenRect.minY + (screenRect.height - startHeight) / 2
            } else {
                x = dockEdgeString == "left" ? screenRect.minX : screenRect.maxX - startWidth
                y = dockEdgeString == "top" ? screenRect.maxY - startHeight : screenRect.minY + (screenRect.height - startHeight) / 2
            }
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
    
    static func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    func promptForAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let _ = AXIsProcessTrustedWithOptions(options)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return !AppDelegate.checkAccessibilityPermission()
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
}
import SwiftUI

struct OnboardingView: View {
    @Environment(\.openURL) var openURL
    @State private var permissionGranted: Bool
    
    init(permissionGranted: Bool = false) {
        self._permissionGranted = State(initialValue: permissionGranted)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 80, height: 80)
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
            
            
            if permissionGranted {
                Text("Permission Granted!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                
                Text("Enjoy the experience. CopyM8 is now active and waiting for your copies.")
                    .multilineTextAlignment(.center)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .padding(.horizontal, 30)
                
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.green)
                    .padding(.top, 10)
            } else {
                Text("Welcome to CopyM8")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                Text("CopyM8 is a keyboard-first clipboard manager.\nTo seamlessly capture your copies in the background and use global hotkeys, CopyM8 requires Accessibility permission.")
                    .multilineTextAlignment(.center)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .padding(.horizontal, 30)
            }
            
            if !permissionGranted {
                VStack(spacing: 16) {
                    Button(action: {
                        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                        let _ = AXIsProcessTrustedWithOptions(options)
                    }) {
                        Text("Grant Permission")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 40)
                            .background(Color.accentColor)
                            .cornerRadius(10)
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    
                    Button("Open System Settings manually") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            openURL(url)
                        }
                    }
                    .buttonStyle(.link)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
                .padding(.top, 10)
            }
        }
        .frame(minWidth: 450, minHeight: 350)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow).ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PermissionGranted"))) { _ in
            withAnimation(.spring()) {
                permissionGranted = true
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
