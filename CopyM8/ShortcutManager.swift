import Foundation
import KeyboardShortcuts
import Combine
import AppKit
import SwiftUI

extension KeyboardShortcuts.Name {
    static let toggleApp = Self("toggleApp", default: .init(.space, modifiers: [.command, .shift]))
    static let openPinned = Self("openPinned")
    static let openGroups = Self("openGroups")
    static let customGlobal1 = Self("customGlobal1")
    static let customGlobal2 = Self("customGlobal2")
    static let customGlobal3 = Self("customGlobal3")
}

/// `ShortcutManager` handles all global keyboard shortcuts for CopyM8.
/// It registers listeners for `KeyboardShortcuts` and triggers state updates such as expanding the app or switching to specific tabs.
class ShortcutManager: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var requestedTab: String? = nil
    @Published var requestedFolder: String? = nil
    @Published var isPresentingModal: Bool = false
    private var eventMonitor: Any?
    
    init() {
        KeyboardShortcuts.onKeyUp(for: .toggleApp) { [weak self] in
            DispatchQueue.main.async {
                self?.isExpanded.toggle()
            }
        }
        
        KeyboardShortcuts.onKeyUp(for: .openPinned) { [weak self] in
            DispatchQueue.main.async {
                self?.requestedTab = "Pinned"
                self?.isExpanded = true
            }
        }
        
        KeyboardShortcuts.onKeyUp(for: .openGroups) { [weak self] in
            DispatchQueue.main.async {
                self?.requestedTab = "Groups"
                self?.isExpanded = true
            }
        }
        
        KeyboardShortcuts.onKeyUp(for: .customGlobal1) { [weak self] in
            self?.handleCustomGlobal(key: "customGlobalTarget1", groupKey: "customGlobalGroup1")
        }
        
        KeyboardShortcuts.onKeyUp(for: .customGlobal2) { [weak self] in
            self?.handleCustomGlobal(key: "customGlobalTarget2", groupKey: "customGlobalGroup2")
        }
        
        KeyboardShortcuts.onKeyUp(for: .customGlobal3) { [weak self] in
            self?.handleCustomGlobal(key: "customGlobalTarget3", groupKey: "customGlobalGroup3")
        }
        
        // Monitor global mouse clicks to dismiss the expanded view
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            DispatchQueue.main.async {
                if self?.isPresentingModal == true { return }
                
                if self?.isExpanded == true {
                    if let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow || $0.isVisible }),
                       window.frame.contains(NSEvent.mouseLocation) {
                        return
                    }
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        self?.isExpanded = false
                        SettingsWindowManager.shared.closeSettings()
                    }
                }
            }
        }
    }
    
    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func handleCustomGlobal(key: String, groupKey: String) {
        let target = UserDefaults.standard.string(forKey: key) ?? ""
        let group = UserDefaults.standard.string(forKey: groupKey) ?? ""
        if !target.isEmpty {
            DispatchQueue.main.async {
                self.requestedTab = target
                if target == "Groups" && !group.isEmpty {
                    self.requestedFolder = group
                } else {
                    self.requestedFolder = nil
                }
                self.isExpanded = true
            }
        }
    }
}
