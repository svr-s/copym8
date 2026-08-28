import SwiftUI
import AppKit

class QueueHUDPanel: NSPanel {
    override var canBecomeKey: Bool {
        return false // CRITICAL: Do not steal typing focus
    }
}

class QueueHUDWindowController: NSWindowController {
    static let shared = QueueHUDWindowController()
    
    private var dismissTimer: Timer?
    private var hudView: QueueHUDView?
    private var hostingController: NSHostingController<AnyView>?
    
    convenience init() {
        let window = QueueHUDPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 160),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.isFloatingPanel = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.canHide = false
        
        self.init(window: window)
    }
    
    func showHUD(with clipboard: ClipboardManager) {
        if self.hudView == nil {
            self.hudView = QueueHUDView()
            let view = AnyView(self.hudView!.environmentObject(clipboard))
            let host = NSHostingController(rootView: view)
            self.hostingController = host
            
            // Apply visual effect wrapper for contrast
            let visualEffect = NSVisualEffectView()
            visualEffect.material = .hudWindow
            visualEffect.state = .active
            visualEffect.blendingMode = .behindWindow
            visualEffect.wantsLayer = true
            visualEffect.layer?.cornerRadius = 12
            visualEffect.clipsToBounds = true
            
            host.view.frame = visualEffect.bounds
            host.view.autoresizingMask = [.width, .height]
            visualEffect.addSubview(host.view)
            
            self.window?.contentView = visualEffect
        }
        
        guard let window = self.window else { return }
        
        // Position at bottom center
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowRect = window.frame
            let x = screenRect.minX + (screenRect.width - windowRect.width) / 2
            let y = screenRect.minY + 40 // 40 points above the dock/bottom
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().alphaValue = 1.0
        }
        
        // Auto-dismiss timer
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            self?.hideHUD()
        }
    }
    
    func hideHUD() {
        guard let window = self.window, window.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window.animator().alphaValue = 0.0
        }) {
            window.orderOut(nil)
        }
    }
}

struct QueueHUDView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Queue Playhead")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            let items = clipboard.queueIDs.compactMap { id in clipboard.history.first(where: { $0.id == id }) }
            let activeIndex = clipboard.queuePlayheadIndex
            
            if items.isEmpty {
                Text("Queue is empty")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 4) {
                    // Show Previous, Current, Next (if they exist)
                    let startIdx = max(0, activeIndex - 1)
                    let endIdx = min(items.count - 1, activeIndex + 1)
                    
                    ForEach(startIdx...endIdx, id: \.self) { idx in
                        let item = items[idx]
                        let status: QueueStatus = {
                            if idx < activeIndex { return .pasted }
                            if idx == activeIndex { return .next }
                            return .upcoming
                        }()
                        
                        QueueHUDRowView(item: item, status: status)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 320)
    }
}

struct QueueHUDRowView: View {
    let item: ClipboardItem
    let status: QueueStatus
    
    var body: some View {
        HStack(spacing: 8) {
            // Status Indicator
            let color: Color = {
                switch status {
                case .next: return .green
                case .upcoming: return .yellow
                case .pasted: return .red
                }
            }()
            
            ZStack(alignment: .center) {
                Rectangle()
                    .fill(color)
                    .frame(width: 3, height: 24)
                    .cornerRadius(1.5)
                
                if status == .next {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.green)
                        .offset(x: 2)
                }
            }
            .frame(width: 12)
            
            // Icon
            Group {
                if item.itemType == .image {
                    Image(systemName: "photo.fill")
                } else if item.itemType == .file {
                    Image(systemName: "doc.fill")
                } else {
                    Image(systemName: "text.alignleft")
                }
            }
            .foregroundColor(.secondary)
            .font(.system(size: 12))
            .frame(width: 16)
            
            // Title
            Text(item.text.replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: 13, weight: status == .next ? .medium : .regular))
                .foregroundColor(status == .next ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(status == .next ? Color.primary.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}
