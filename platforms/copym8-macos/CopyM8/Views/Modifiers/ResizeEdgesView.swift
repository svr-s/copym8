import SwiftUI
import AppKit

struct ResizeEdgesView: View {
    @Binding var windowWidth: Double
    @Binding var windowHeight: Double
    @Binding var isResizing: Bool
    @Binding var resizeStartMouse: NSPoint?
    @Binding var resizeStartSize: NSSize?
    @State private var resizeStartFrame: NSRect?
    var adjustWindowFrame: () -> Void
    
    let resizeThickness: CGFloat = 8
    
    var body: some View {
        ZStack {
            // Right edge
            Color.clear
                .frame(width: resizeThickness)
                .contentShape(Rectangle())
                .onHover { hover in if hover { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
                .gesture(resizeGesture(edge: .right))
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            // Left edge
            Color.clear
                .frame(width: resizeThickness)
                .contentShape(Rectangle())
                .onHover { hover in if hover { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
                .gesture(resizeGesture(edge: .left))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Bottom edge
            Color.clear
                .frame(height: resizeThickness)
                .contentShape(Rectangle())
                .onHover { hover in if hover { NSCursor.resizeUpDown.push() } else { NSCursor.pop() } }
                .gesture(resizeGesture(edge: .bottom))
                .frame(maxHeight: .infinity, alignment: .bottom)
                
            // Top edge
            Color.clear
                .frame(height: resizeThickness)
                .contentShape(Rectangle())
                .onHover { hover in if hover { NSCursor.resizeUpDown.push() } else { NSCursor.pop() } }
                .gesture(resizeGesture(edge: .top))
                .frame(maxHeight: .infinity, alignment: .top)
                
            // Bottom Right Corner
            Color.clear
                .frame(width: resizeThickness * 2, height: resizeThickness * 2)
                .contentShape(Rectangle())
                .onHover { hover in if hover { NSCursor.crosshair.push() } else { NSCursor.pop() } }
                .gesture(resizeGesture(edge: .bottomRight))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }
    
    enum ResizeEdge { case left, right, bottom, top, bottomRight }
    
    private func resizeGesture(edge: ResizeEdge) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isResizing {
                    isResizing = true
                    resizeStartMouse = NSEvent.mouseLocation
                    resizeStartSize = NSSize(width: windowWidth, height: windowHeight)
                    if let win = NSApp.windows.first {
                        resizeStartFrame = win.frame
                    }
                }
                guard let startMouse = resizeStartMouse, let startSize = resizeStartSize,
                      let startFrame = resizeStartFrame,
                      let window = NSApp.windows.first, let screenRect = window.screen?.visibleFrame else { return }
                
                let currentMouse = NSEvent.mouseLocation
                let dx = currentMouse.x - startMouse.x
                let dy = currentMouse.y - startMouse.y
                
                let maxWidth = screenRect.width
                let maxHeight = screenRect.height
                
                var newFrame = startFrame
                
                switch edge {
                case .right:
                    windowWidth = min(maxWidth, max(340, startSize.width + dx))
                    newFrame.size.width = windowWidth
                case .left:
                    windowWidth = min(maxWidth, max(340, startSize.width - dx))
                    newFrame.size.width = windowWidth
                    newFrame.origin.x = startFrame.maxX - windowWidth
                case .bottom:
                    windowHeight = min(maxHeight, max(300, startSize.height - dy)) 
                    newFrame.size.height = windowHeight
                    newFrame.origin.y = startFrame.maxY - windowHeight
                case .top:
                    windowHeight = min(maxHeight, max(300, startSize.height + dy))
                    newFrame.size.height = windowHeight
                    // Origin y stays the same (bottom edge fixed)
                case .bottomRight:
                    windowWidth = min(maxWidth, max(340, startSize.width + dx))
                    windowHeight = min(maxHeight, max(300, startSize.height - dy))
                    newFrame.size.width = windowWidth
                    newFrame.size.height = windowHeight
                    newFrame.origin.y = startFrame.maxY - windowHeight
                }
                
                window.setFrame(newFrame, display: true, animate: false)
            }
            .onEnded { _ in
                isResizing = false
                resizeStartMouse = nil
                resizeStartSize = nil
                resizeStartFrame = nil
                NSCursor.pop()
            }
    }
}

// MARK: - Settings View
