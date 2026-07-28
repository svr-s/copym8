import Foundation
import KeyboardShortcuts
import Combine
import AppKit
import SwiftUI

extension KeyboardShortcuts.Name {
    static let toggleApp = Self("toggleApp", default: .init(.space, modifiers: [.command, .shift]))
    static let openPinned = Self("openPinned")
    static let openGroups = Self("openGroups")
}

class ShortcutManager: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var requestedTab: String? = nil
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
}
