import SwiftUI
import AppKit

/// `NativeDragView` is an `NSViewRepresentable` wrapper that enables seamless, lag-free native window dragging.
/// It works by intercepting mouse events and moving the `NSWindow` natively, bypassing SwiftUI's gesture system.
struct NativeDragView: NSViewRepresentable {
    var onDragEnded: () -> Void
    var onTap: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = DragTrackingView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? DragTrackingView {
            view.onDragEnded = onDragEnded
            view.onTap = onTap
        }
    }
}

class DragTrackingView: NSView {
    var onDragEnded: (() -> Void)?
    var onTap: (() -> Void)?

    private var startLocation: NSPoint = .zero
    private var startOrigin: NSPoint = .zero
    private var isDragging: Bool = false

    override var acceptsFirstResponder: Bool { true }
    
    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }
        startLocation = NSEvent.mouseLocation
        startOrigin = window.frame.origin
        isDragging = false
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window else { return }
        let currentLocation = NSEvent.mouseLocation
        let dx = currentLocation.x - startLocation.x
        let dy = currentLocation.y - startLocation.y
        
        if !isDragging && (abs(dx) > 3 || abs(dy) > 3) {
            isDragging = true
        }
        
        if isDragging {
            let screenRect = window.screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 10000, height: 10000)
            var newOrigin = NSPoint(x: startOrigin.x + dx, y: startOrigin.y + dy)
            newOrigin.x = max(screenRect.minX, min(newOrigin.x, screenRect.maxX - window.frame.width))
            newOrigin.y = max(screenRect.minY, min(newOrigin.y, screenRect.maxY - window.frame.height))
            window.setFrameOrigin(newOrigin)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if !isDragging {
            DispatchQueue.main.async { self.onTap?() }
        } else {
            DispatchQueue.main.async { self.onDragEnded?() }
        }
        isDragging = false
    }
}

// MARK: - Resize Edges View
