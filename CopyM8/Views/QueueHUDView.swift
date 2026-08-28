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
        
        // Instant appearance
        window.alphaValue = 1.0
        window.makeKeyAndOrderFront(nil)
        
        // Auto-dismiss timer (increased to 2.5s)
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            self?.hideHUD()
        }
    }
    
    func hideHUD() {
        guard let window = self.window, window.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5 // Slower fade out
            window.animator().alphaValue = 0.0
        }) {
            window.orderOut(nil)
        }
    }
}

struct QueueHUDView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Side: Logo Pill
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: 28) // Tighter pill
                
                Image("CopyM8_Logo_Crescent_8")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(clipboard.isQueueRecording ? .red : .primary.opacity(0.8))
                    .frame(width: 16, height: 16) // Adjust to fit
            }
            .padding(.leading, 6)
            .padding(.vertical, 6)
            
            // Right Side: List
            VStack(spacing: 2) { // Tighter spacing
                let items = clipboard.queueIDs.compactMap { id in clipboard.history.first(where: { $0.id == id }) }
                let activeIndex = clipboard.queuePlayheadIndex
                
                if items.isEmpty {
                    Text("Queue is empty")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                } else {
                    // Always show 5 slots: activeIndex - 2 to activeIndex + 2
                    ForEach(-2...2, id: \.self) { offset in
                        let targetIndex = activeIndex + offset
                        if targetIndex >= 0 && targetIndex < items.count {
                            let item = items[targetIndex]
                            let status: QueueStatus = {
                                if offset < 0 { return .pasted }
                                if offset == 0 { return .next }
                                return .upcoming
                            }()
                            QueueHUDRowView(item: item, status: status)
                        } else {
                            // Empty slot to maintain layout height
                            Color.clear.frame(height: 26) // precise height of concise row
                        }
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
        }
        .frame(width: 280) // Tighter width
    }
}

struct QueueHUDRowView: View {
    let item: ClipboardItem
    let status: QueueStatus
    
    private var primaryTextColor: Color {
        status == .next ? .white : .primary.opacity(0.95)
    }
    
    private var titleText: String {
        if (item.itemType == .file || item.itemType == .image), let range = item.text.range(of: " (", options: .backwards) {
            return String(item.text[..<range.lowerBound])
        }
        return item.text
    }
    
    private var filenameText: String {
        let title = titleText
        if title.hasSuffix(" more"), let range = title.range(of: " + ", options: .backwards) {
            return String(title[..<range.lowerBound])
        }
        return title
    }
    
    private var suffixText: String? {
        let title = titleText
        if title.hasSuffix(" more"), let range = title.range(of: " + ", options: .backwards) {
            return String(title[range.lowerBound...])
        }
        return nil
    }
    
    private var metaText: String? {
        if (item.itemType == .file || item.itemType == .image), let range = item.text.range(of: " (", options: .backwards) {
            return String(item.text[range.lowerBound...])
        }
        return nil
    }
    
    @ViewBuilder
    private var titleAndMetaView: some View {
        HStack(spacing: 0) {
            Text(filenameText)
                .lineLimit(1)
                .truncationMode((item.itemType == .file || item.itemType == .image) ? .middle : .tail)
            
            if let suffix = suffixText {
                Text(suffix).lineLimit(1).layoutPriority(1)
            }
            
            if let meta = metaText {
                Text(meta).lineLimit(1).layoutPriority(1)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 13, weight: .regular))
        .foregroundColor(primaryTextColor)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            if item.itemType == .image {
                if let paths = item.fileURLs, paths.count > 1 {
                    Image(systemName: "photo.on.rectangle.angled")
                        .resizable().scaledToFit().frame(width: 16, height: 16)
                        .foregroundColor(status == .next ? .white.opacity(0.8) : .secondary)
                } else {
                    Image(systemName: "photo.fill")
                        .resizable().scaledToFit().frame(width: 16, height: 16)
                        .foregroundColor(status == .next ? .white.opacity(0.8) : .secondary)
                }
                titleAndMetaView
            } else if item.itemType == .file, let paths = item.fileURLs, let path = paths.first {
                if paths.count > 1 {
                    Image(systemName: "doc.on.doc.fill")
                        .resizable().scaledToFit().frame(width: 16, height: 16)
                        .foregroundColor(status == .next ? .white.opacity(0.8) : .secondary)
                } else {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                        .resizable().frame(width: 16, height: 16)
                }
                titleAndMetaView
            } else {
                titleAndMetaView
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(status == .next ? Color(nsColor: .selectedContentBackgroundColor) : Color.clear)
        .cornerRadius(6)
        .overlay(
            Group {
                let color: Color = {
                    switch status {
                    case .next: return .green
                    case .upcoming: return .yellow
                    case .pasted: return .red
                    }
                }()
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(color)
                        .frame(width: 3)
                    
                    if status == .next {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.green)
                            .offset(x: 1.5)
                    }
                }
            },
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
