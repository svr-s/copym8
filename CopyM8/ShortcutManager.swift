import Foundation
import HotKey
import Combine
import AppKit

class ShortcutManager: ObservableObject {
    @Published var isExpanded: Bool = false
    private var hotKey: HotKey?
    private var eventMonitor: Any?
    
    init() {
        // Super+Shift+Space on Mac (Command+Shift+Space)
        hotKey = HotKey(key: .space, modifiers: [.command, .shift])
        
        hotKey?.keyDownHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.isExpanded.toggle()
            }
        }
        
        // Monitor global mouse clicks to dismiss the expanded view
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            DispatchQueue.main.async {
                if self?.isExpanded == true {
                    self?.isExpanded = false
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
