import SwiftUI
import AppKit

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

    override var acceptsFirstResponder: Bool { true }
    
    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }
        let startLocation = NSEvent.mouseLocation
        let startOrigin = window.frame.origin
        var isDragging = false
        
        // Modal event loop for zero-lag drag that respects screen boundaries
        var keepOn = true
        while keepOn {
            guard let nextEvent = window.nextEvent(matching: [.leftMouseUp, .leftMouseDragged], until: .distantFuture, inMode: .eventTracking, dequeue: true) else { continue }
            
            switch nextEvent.type {
            case .leftMouseDragged:
                let currentLocation = NSEvent.mouseLocation
                let dx = currentLocation.x - startLocation.x
                let dy = currentLocation.y - startLocation.y
                
                if !isDragging && (abs(dx) > 3 || abs(dy) > 3) {
                    isDragging = true
                }
                
                if isDragging {
                    let screenRect = window.screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 10000, height: 10000)
                    var newOrigin = NSPoint(x: startOrigin.x + dx, y: startOrigin.y + dy)
                    // Strictly constrain to screen
                    newOrigin.x = max(screenRect.minX, min(newOrigin.x, screenRect.maxX - window.frame.width))
                    newOrigin.y = max(screenRect.minY, min(newOrigin.y, screenRect.maxY - window.frame.height))
                    window.setFrameOrigin(newOrigin)
                }
                
            case .leftMouseUp:
                keepOn = false
                if !isDragging {
                    DispatchQueue.main.async { self.onTap?() }
                } else {
                    DispatchQueue.main.async { self.onDragEnded?() }
                }
                
            default:
                break
            }
        }
    }
}

// MARK: - Resize Edges View
