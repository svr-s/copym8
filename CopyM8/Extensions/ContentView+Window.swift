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

    func adjustWindowFrame(expanded: Bool, animate: Bool = true) {
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
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
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
        
        var targetX = windowRect.origin.x
        let targetY = windowRect.origin.y // Vertical remains untouched in Phase 1
        
        if distLeft < distRight { 
            dockEdgeRaw = "left"
            targetX = screenRect.minX 
        } else { 
            dockEdgeRaw = "right"
            targetX = screenRect.maxX - windowRect.width 
        }
        
        if !shortcut.isExpanded {
            let width: CGFloat = 28
            let height: CGFloat = 40
            window.setContentSize(NSSize(width: width, height: height))
            if dockEdgeRaw == "left" { targetX = screenRect.minX }
            if dockEdgeRaw == "right" { targetX = screenRect.maxX - width }
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 1.2, 0.4, 1.0) // Bouncy spring curve
            window.animator().setFrameOrigin(NSPoint(x: targetX, y: targetY))
        }
    }

}
