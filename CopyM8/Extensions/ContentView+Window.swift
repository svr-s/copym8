import SwiftUI
import AppKit

extension ContentView {
    func getDynamicWindowSize() -> CGSize {
        let calculatedHeight = windowHeight
        var finalWidth = max(340, windowWidth)
        var finalHeight = calculatedHeight
        if let screenRect = NSApp.windows.first(where: { $0 is CopyM8Window })?.screen?.visibleFrame {
            finalWidth = min(finalWidth, screenRect.width)
            finalHeight = min(finalHeight, screenRect.height)
        }
        return CGSize(width: finalWidth, height: finalHeight)
    }

    func adjustWindowFrame(expanded: Bool, animate: Bool = true, bouncy: Bool = false) {
        guard let window = NSApp.windows.first(where: { $0 is CopyM8Window }) ?? NSApp.windows.first else { return }
        let isTop = dockEdge == .top
        let pillWidth: CGFloat = isTop ? 40 : 28
        let pillHeight: CGFloat = isTop ? 28 : 40
        let newSize = expanded ? getDynamicWindowSize() : NSSize(width: pillWidth, height: pillHeight)
        var frame = window.frame
        let oldWidth = frame.width
        let oldHeight = frame.height
        
        switch dockEdge {
        case .right:
            frame.origin.y -= (newSize.height - oldHeight) / 2
            if !expanded, let screenRect = window.screen?.visibleFrame {
                frame.origin.x = screenRect.maxX - newSize.width
            } else {
                frame.origin.x -= (newSize.width - oldWidth)
            }
        case .left:
            frame.origin.y -= (newSize.height - oldHeight) / 2
            if !expanded, let screenRect = window.screen?.visibleFrame {
                frame.origin.x = screenRect.minX
            }
        case .top:
            frame.origin.x -= (newSize.width - oldWidth) / 2
            if !expanded, let screenRect = window.screen?.visibleFrame {
                frame.origin.y = screenRect.maxY - newSize.height
            } else {
                frame.origin.y -= (newSize.height - oldHeight) / 2
            }
        }
        frame.size = newSize
        
        if let screenRect = window.screen?.visibleFrame {
            frame.origin.x = max(screenRect.minX, min(frame.origin.x, screenRect.maxX - frame.width))
            frame.origin.y = max(screenRect.minY, min(frame.origin.y, screenRect.maxY - frame.height))
        }
        if animate {
            NSAnimationContext.runAnimationGroup { context in
                if bouncy {
                    context.duration = 0.5
                    context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 1.2, 0.4, 1.0)
                } else {
                    context.duration = 0.3
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                }
                window.animator().setFrame(frame, display: true)
            }
        } else {
            window.setFrame(frame, display: true, animate: false)
        }
        
        if !expanded {
            DispatchQueue.main.asyncAfter(deadline: .now() + (animate ? 0.4 : 0.1)) {
                if clipboard.selectedDevice != "Local (This Mac)" {
                    clipboard.selectedDevice = "Local (This Mac)"
                }
            }
        }
    }

    func snapToEdge() {
        guard let window = NSApp.windows.first(where: { $0 is CopyM8Window }) ?? NSApp.windows.first, let screen = window.screen else { return }
        let screenRect = screen.visibleFrame
        let windowRect = window.frame
        let center = NSPoint(x: windowRect.midX, y: windowRect.midY)
        
        let distLeft = center.x - screenRect.minX
        let distRight = screenRect.maxX - center.x
        
        // Phase 1: Only check left vs right edges
        if distLeft < distRight { 
            dockEdgeRaw = "left" 
        } else { 
            dockEdgeRaw = "right" 
        }
        
        // Delegate the actual physical movement and resizing to adjustWindowFrame,
        // which reliably sets both origin and size, respecting SwiftUI's layout cycle.
        // If the pill isn't expanded, we use the bouncy spring animation!
        if !shortcut.isExpanded {
            adjustWindowFrame(expanded: false, animate: true, bouncy: true)
        }
    }

}
