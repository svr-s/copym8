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
        
        if !checkAccessibilityPermission() {
            showOnboardingWindow()
        } else {
            setupMainWindow()
        }
    }
    
    func showOnboardingWindow() {
        NSApp.activate(ignoringOtherApps: true)
        let onboardingView = OnboardingView()
        
        onboardingWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 350),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        onboardingWindow?.title = "Welcome to CopyM8"
        onboardingWindow?.isReleasedWhenClosed = false
        onboardingWindow?.center()
        
        let hostingView = NSHostingView(rootView: onboardingView)
        onboardingWindow?.contentView = hostingView
        onboardingWindow?.makeKeyAndOrderFront(nil)
        
        // Start polling for accessibility permission
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            if self?.checkAccessibilityPermission() == true {
                DispatchQueue.main.async {
                    self?.accessibilityTimer?.invalidate()
                    self?.accessibilityTimer = nil
                    
                    // Activate and bring to front
                    NSApp.activate(ignoringOtherApps: true)
                    self?.onboardingWindow?.makeKeyAndOrderFront(nil)
                    
                    // Post notification to update UI
                    NotificationCenter.default.post(name: NSNotification.Name("PermissionGranted"), object: nil)
                    
                    // Wait 1.5s for the user to read the message, then animate the transition
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self?.onboardingWindow?.close()
                        self?.onboardingWindow = nil
                        self?.setupMainWindow(animateFromCenter: true)
                    }
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        accessibilityTimer = timer
    }
    
    func setupMainWindow(animateFromCenter: Bool = false) {
        ShortcutManager.initialExpand = false
        let contentView = ContentView()
        
        let dockEdgeString = UserDefaults.standard.string(forKey: "dockEdge") ?? "right"
        let isTop = dockEdgeString == "top"
        let pillWidth: CGFloat = isTop ? 40 : 28
        let pillHeight: CGFloat = isTop ? 28 : 40
        
        if animateFromCenter {
            // Spawn borderless window at center of screen, size of onboarding view
            window = CopyM8Window(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 350),
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
            
            // Set OnboardingView as the content
            let onboardingView = OnboardingView(permissionGranted: true)
            let hostingView = NSHostingView(rootView: onboardingView)
            hostingView.layer?.backgroundColor = NSColor.clear.cgColor
            window.contentView = hostingView
            
            window.center()
            window.orderFront(nil)
            
            // Wait 1s (plus 1.5s from previous step = 2.5s total reading time), then shrink to edge
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let screenRect = self.window?.screen?.visibleFrame {
                    let targetX = screenRect.maxX - 28
                    let targetY = screenRect.minY + (screenRect.height - 72) / 2
                    let targetFrame = NSRect(x: targetX, y: targetY, width: pillWidth, height: pillHeight)
                    
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.6
                        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                        self.window?.animator().setFrame(targetFrame, display: true)
                    }, completionHandler: {
                        // Once at the edge, swap content to ContentView (which renders as a pill by default)
                        let newHostingView = NSHostingView(rootView: contentView)
                        newHostingView.layer?.backgroundColor = NSColor.clear.cgColor
                        self.window?.contentView = newHostingView
                        
                        // Wait a tiny bit and pop open
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            NotificationCenter.default.post(name: NSNotification.Name("ForceExpand"), object: nil)
                        }
                    })
                }
            }
        } else {
            // Normal startup at the edge
            window = CopyM8Window(
                contentRect: NSRect(x: 0, y: 0, width: pillWidth, height: pillHeight),
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
                let x = screenRect.maxX - 28
                let y = screenRect.minY + (screenRect.height - 72) / 2
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
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
    
    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    func promptForAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let _ = AXIsProcessTrustedWithOptions(options)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // If we don't have accessibility permissions and the onboarding window is closed, quit the app.
        return !checkAccessibilityPermission()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !checkAccessibilityPermission() {
            if onboardingWindow == nil {
                showOnboardingWindow()
            } else {
                onboardingWindow?.makeKeyAndOrderFront(nil)
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
