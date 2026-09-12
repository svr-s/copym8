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
    var onboardingController: OnboardingWindowController?
    var accessibilityTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "maxBackupsCount": 3
        ])
        
        let hasPermission = AppDelegate.checkAccessibilityPermission()
        ShortcutManager.initialExpand = false // Always start as pill
        setupMainWindow()
        
        if !hasPermission {
            showOnboardingWindow()
            startAccessibilityTimer()
            // Hide the pill while onboarding is active — it will appear once the user clicks "Open CopyM8"
            window.orderOut(nil)
        }
    }
    
    /// Displays a standalone onboarding window centered on screen.
    /// This window is completely independent from the main pill window.
    func showOnboardingWindow() {
        let onboardingView = OnboardingView()
        let hosting = NSHostingView(rootView: onboardingView)
        
        let windowWidth: CGFloat = 480
        let windowHeight: CGFloat = 400
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = true
        win.contentView = hosting
        win.center()
        win.level = .floating
        
        let controller = OnboardingWindowController()
        win.delegate = controller
        onboardingController = controller
        onboardingWindow = win
        
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }
    
    func startAccessibilityTimer() {
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            if AppDelegate.checkAccessibilityPermission() {
                DispatchQueue.main.async {
                    self?.accessibilityTimer?.invalidate()
                    self?.accessibilityTimer = nil
                    
                    // Notify the onboarding window to show the success state
                    NotificationCenter.default.post(name: NSNotification.Name("PermissionGranted"), object: nil)
                    // Re-focus the onboarding window so user sees the "Permission Granted!" screen
                    NSApp.activate(ignoringOtherApps: true)
                    self?.onboardingWindow?.makeKeyAndOrderFront(nil)
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
        
        // Always start as pill — onboarding is handled by a separate window
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

/// Delegate that manages the lifecycle of the standalone onboarding window.
/// Handles dismiss (click outside or ESC → window resigns key) and the explicit launch sequence.
class OnboardingWindowController: NSObject, NSWindowDelegate {
    /// Set to true once `PermissionGranted` notification is received during this onboarding session.
    private var permissionGranted: Bool = false
    private var observers: [Any] = []
    
    override init() {
        super.init()
        
        // Track when permissions are granted so we can suppress the resign-key auto-dismiss
        observers.append(NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PermissionGranted"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.permissionGranted = true
        })
        
        // "Open CopyM8" button tapped — close the onboarding window and expand CopyM8
        observers.append(NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LaunchCopyM8"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, let app = NSApp.delegate as? AppDelegate else { return }
            self.launchCopyM8(win: app.onboardingWindow)
        })
    }
    
    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    /// The onboarding window stays open until the user explicitly closes it (title bar close button)
    /// or clicks "Open CopyM8". We do NOT auto-dismiss on resign-key because the user needs to
    /// switch to System Settings to grant permission and come back — the window must stay visible.
    /// windowDidResignKey intentionally not implemented.
    
    /// Closes the onboarding window, shows the pill at the right edge, then expands CopyM8.
    private func launchCopyM8(win: NSWindow?) {
        win?.orderOut(nil)
        // Show the pill at the right edge
        if let app = NSApp.delegate as? AppDelegate {
            app.window?.orderFront(nil)
        }
        // Brief pause so the pill is visible before expanding
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            NotificationCenter.default.post(name: NSNotification.Name("ForceExpand"), object: nil)
        }
    }
}

struct OnboardingView: View {
    @State private var permissionGranted: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 80, height: 80)
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
            
            
            if permissionGranted {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.green)
                    Text("Permission Granted!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
                
                Text("Enjoy the experience. CopyM8 is now active and waiting for your copies.")
                    .multilineTextAlignment(.center)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .padding(.horizontal, 30)
                
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("LaunchCopyM8"), object: nil)
                }) {
                    Text("Open CopyM8")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 40)
                        .background(Color.green)
                        .cornerRadius(10)
                        .shadow(color: Color.green.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
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
                        // Open System Settings directly — avoids the system dialog appearing behind the window
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
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
                            NSWorkspace.shared.open(url)
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
