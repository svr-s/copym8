import SwiftUI
import AppKit

struct KeyboardMonitorModifier: ViewModifier {
    let onKeyDown: (NSEvent) -> NSEvent?
    
    // Holds the latest closure so we don't capture stale state in the event monitor
    private class ClosureWrapper {
        var closure: ((NSEvent) -> NSEvent?)?
    }
    
    @State private var wrapper = ClosureWrapper()
    @State private var localEventMonitor: Any?

    func body(content: Content) -> some View {
        // Update the wrapper with the latest closure on every evaluation
        DispatchQueue.main.async {
            wrapper.closure = onKeyDown
        }
        
        return content
            .onAppear {
                wrapper.closure = onKeyDown
                localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if let closure = wrapper.closure {
                        return closure(event)
                    }
                    return event
                }
            }
            .onDisappear {
                if let monitor = localEventMonitor {
                    NSEvent.removeMonitor(monitor)
                    localEventMonitor = nil
                }
            }
    }
}

extension View {
    func onCustomKeyPress(_ action: @escaping (NSEvent) -> NSEvent?) -> some View {
        self.modifier(KeyboardMonitorModifier(onKeyDown: action))
    }
}
