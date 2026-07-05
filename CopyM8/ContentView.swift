import SwiftUI
import AppKit

enum DockEdge {
    case left, right, top
}

struct ContentView: View {
    @StateObject private var clipboard = ClipboardManager()
    @StateObject private var shortcut = ShortcutManager()
    @State private var isHovering = false
    @State private var showingClearAlert = false
    @State private var showingEmptyToast = false
    @State private var expandedItemIndex: Int? = nil
    
    // UI State
    @AppStorage("activeColorName") private var activeColorName: String = "Glacier"
    @AppStorage("isDense") private var isDense: Bool = true
    @AppStorage("dockEdgeRaw") private var dockEdgeRaw: String = "right"
    @AppStorage("windowWidth") private var windowWidth: Double = 320
    @AppStorage("windowHeight") private var windowHeight: Double = 420
    
    // Derived UI State
    private var dockEdge: DockEdge {
        switch dockEdgeRaw {
        case "left": return .left
        case "top": return .top
        default: return .right
        }
    }
    
    private var activeColor: Color {
        colors.first(where: { $0.name == activeColorName })?.color ?? .cyan
    }
    
    // Drag State
    @State private var dragOffset: CGSize = .zero
    @State private var initialWindowPosition: NSPoint? = nil
    
    // Keyboard Selection
    @State private var selectedIndex: Int = 0
    // Resize State
    @State private var isResizing = false
    @State private var resizeStartMouse: NSPoint?
    @State private var resizeStartSize: NSSize?
    
    // Hover State for Close
    @State private var isHoveringClose = false
    
    let colors: [(name: String, color: Color)] = [
        ("Ocean", Color(red: 0.2, green: 0.6, blue: 0.8)),
        ("Peach", Color(red: 0.9, green: 0.6, blue: 0.5)),
        ("Lavender", Color(red: 0.7, green: 0.5, blue: 0.8)),
        ("Mint", Color(red: 0.4, green: 0.8, blue: 0.6)),
        ("Lemon", Color(red: 0.9, green: 0.8, blue: 0.4)),
        ("Bubblegum", Color(red: 0.9, green: 0.4, blue: 0.6))
    ]
    
    var body: some View {
        ZStack {
            if shortcut.isExpanded {
                expandedView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                pillView
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .background(Color.clear)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: shortcut.isExpanded)
        .onChange(of: shortcut.isExpanded) { expanded in
            adjustWindowFrame(expanded: expanded)
            if expanded {
                previousApp = NSWorkspace.shared.frontmostApplication
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
                setupKeyboardMonitor()
            } else {
                teardownKeyboardMonitor()
            }
        }
    }
    
    // MARK: - Expanded View
    private var expandedView: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                // Close button (Mac style traffic light)
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                    
                    if isHoveringClose {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .black))
                            .foregroundColor(.black.opacity(0.6))
                    }
                }
                .onHover { hover in
                    isHoveringClose = hover
                    if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .onTapGesture {
                    NSApplication.shared.terminate(nil)
                }
                
                // Clear All Button
                Button(action: {
                    if clipboard.history.isEmpty {
                        withAnimation { showingEmptyToast = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showingEmptyToast = false }
                        }
                    } else {
                        showingClearAlert = true
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hover in
                    if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .alert("Clear all copied items?", isPresented: $showingClearAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Clear", role: .destructive) { clipboard.clearAll() }
                }
                
                Spacer()
                
                // Spacing toggle
                HStack(spacing: 0) {
                    Text("Dense")
                        .font(.system(size: 9, weight: isDense ? .bold : .regular))
                        .foregroundColor(isDense ? .white : .white.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(isDense ? Color.white.opacity(0.15) : Color.clear)
                        .cornerRadius(4)
                        .onTapGesture { isDense = true }
                    
                    Text("Spaced")
                        .font(.system(size: 9, weight: !isDense ? .bold : .regular))
                        .foregroundColor(!isDense ? .white : .white.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(!isDense ? Color.white.opacity(0.15) : Color.clear)
                        .cornerRadius(4)
                        .onTapGesture { isDense = false }
                }
                .background(Color.black.opacity(0.2))
                .cornerRadius(4)
                
                Divider().frame(height: 12).background(Color.white.opacity(0.2))
                
                // Color Palette
                HStack(spacing: 6) {
                    ForEach(colors, id: \.name) { c in
                        Circle()
                            .fill(c.name == "Clear" ? Color.white.opacity(0.1) : c.color)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: activeColorName == c.name ? 2 : 0)
                            )
                            .onTapGesture { activeColorName = c.name }
                    }
                }
                
                Divider().frame(height: 12).background(Color.white.opacity(0.2))
                
                // Reset Size Button
                Button(action: {
                    withAnimation(.spring()) {
                        windowWidth = 320
                        windowHeight = 420
                        adjustWindowFrame(expanded: true)
                    }
                }) {
                    Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(VisualEffectView(material: .popover, blendingMode: .behindWindow).opacity(0.5))
            
            .overlay(
                Group {
                    if showingEmptyToast {
                        Text("Nothing to delete")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .offset(y: 10)
                    }
                }, alignment: .top
            )
            if clipboard.history.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.bottom, 4)
                    Text("Your clipboard is empty.\nStart copying to see items here!")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: isDense ? 2 : 12) {
                        ForEach(Array(clipboard.history.enumerated()), id: \.element.id) { (index: Int, item: ClipboardItem) in
                            ClipboardItemView(
                                index: index,
                                item: item,
                                isSelected: index == selectedIndex,
                                isExpanded: index == expandedItemIndex,
                                isDense: isDense,
                                activeColor: activeColor,
                                onPaste: {
                                    pasteItem(index: index)
                                },
                                onExpandToggle: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if expandedItemIndex == index {
                                            expandedItemIndex = nil
                                        } else {
                                            expandedItemIndex = index
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(8)
                }
            }
            
            // Native Drag Area in empty space
            Color.clear
                .contentShape(Rectangle())
                .frame(maxHeight: .infinity)
                .overlay(
                    NativeDragView(
                        onDragBegan: {},
                        onDragEnded: { snapToEdge() },
                        onTap: {}
                    )
                )
        }
        .frame(width: getDynamicWindowSize().width, height: getDynamicWindowSize().height)
        .background(
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .behindWindow)
                activeColor.opacity(0.08)
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        // Add custom Resize Edges view back
        .overlay(
            ResizeEdgesView(
                windowWidth: $windowWidth,
                windowHeight: $windowHeight,
                isResizing: $isResizing,
                resizeStartMouse: $resizeStartMouse,
                resizeStartSize: $resizeStartSize,
                adjustWindowFrame: { adjustWindowFrame(expanded: true) }
            )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Pill View
    private var pillView: some View {
        let isTop = dockEdge == .top
        let width: CGFloat = isTop ? 72 : 28
        let height: CGFloat = isTop ? 28 : 72
        
        return RoundedRectangle(cornerRadius: 24)
            .fill(Color.clear)
            .background(
                ZStack {
                    VisualEffectView(material: .popover, blendingMode: .behindWindow)
                    activeColor.opacity(isHovering ? 0.3 : 0.1)
                    NativeDragView(
                        onDragBegan: {},
                        onDragEnded: { snapToEdge() },
                        onTap: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                shortcut.isExpanded = true
                            }
                        }
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(isHovering ? 0.5 : 0.25), lineWidth: 1)
            )
            .shadow(color: activeColor.opacity(0.3), radius: 10, x: 0, y: 5)
            .overlay(
                Text("CM8")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(activeColor)
                    .opacity(0.5)
                    .rotationEffect(.degrees(isTop ? 0 : (dockEdge == .left ? -90 : 90)))
            )
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isHovering = hovering
                }
            }
            .contentShape(Rectangle())
    }
    
    // MARK: - Dynamic Size
    private func getDynamicWindowSize() -> CGSize {
        // If empty, return a small size
        if clipboard.history.isEmpty {
            return CGSize(width: windowWidth, height: 150)
        }
        
        let headerHeight: CGFloat = 40
        let itemHeight: CGFloat = isDense ? 28 : 44
        let totalItemsHeight = CGFloat(clipboard.history.count) * itemHeight + 20
        let calculatedHeight = min(windowHeight, headerHeight + totalItemsHeight)
        
        return CGSize(width: windowWidth, height: calculatedHeight)
    }
    
    // MARK: - Magnetic Dragging
    private func snapToEdge() {
        guard let window = NSApp.windows.first, let screen = window.screen else { return }
        
        let screenRect = screen.visibleFrame
        let windowRect = window.frame
        
        let center = NSPoint(x: windowRect.midX, y: windowRect.midY)
        
        let distLeft = center.x - screenRect.minX
        let distRight = screenRect.maxX - center.x
        let distTop = screenRect.maxY - center.y
        
        // Find closest edge
        let minEdge = min(distLeft, distRight, distTop)
        
        var targetEdge: DockEdge = .right
        var targetX = windowRect.origin.x
        var targetY = windowRect.origin.y
        
        if minEdge == distLeft {
            dockEdgeRaw = "left"
            targetX = screenRect.minX
        } else if minEdge == distRight {
            dockEdgeRaw = "right"
            targetX = screenRect.maxX - windowRect.width
        } else {
            dockEdgeRaw = "top"
            targetY = screenRect.maxY - windowRect.height
        }
        
        // If it's closed, we need to adjust size based on orientation change
        if !shortcut.isExpanded {
            let isTop = dockEdgeRaw == "top"
            let width: CGFloat = isTop ? 72 : 28
            let height: CGFloat = isTop ? 28 : 72
            window.setContentSize(NSSize(width: width, height: height))
            
            // Recalculate snap position with new size
            if dockEdgeRaw == "left" { targetX = screenRect.minX }
            if dockEdgeRaw == "right" { targetX = screenRect.maxX - width }
            if dockEdgeRaw == "top" { targetY = screenRect.maxY - height }
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrameOrigin(NSPoint(x: targetX, y: targetY))
        }
    }
    
    private func adjustWindowFrame(expanded: Bool) {
        guard let window = NSApp.windows.first else { return }
        
        let isTop = dockEdge == .top
        let pillWidth: CGFloat = isTop ? 72 : 28
        let pillHeight: CGFloat = isTop ? 28 : 72
        
        let newSize = expanded ? getDynamicWindowSize() : NSSize(width: pillWidth, height: pillHeight)
        var frame = window.frame
        
        let oldWidth = frame.width
        let oldHeight = frame.height
        
        // Adjust origin based on dock edge
        switch dockEdge {
        case .right:
            frame.origin.x -= (newSize.width - oldWidth)
            frame.origin.y -= (newSize.height - oldHeight) / 2
        case .left:
            frame.origin.y -= (newSize.height - oldHeight) / 2
        case .top:
            frame.origin.x -= (newSize.width - oldWidth) / 2
            frame.origin.y -= (newSize.height - oldHeight)
        }
        
        frame.size = newSize
        window.setFrame(frame, display: true, animate: true)
    }
    
    // MARK: - Keyboard Monitor
    @State private var eventMonitor: Any?
    @State private var previousApp: NSRunningApplication?
    
    private func setupKeyboardMonitor() {
        selectedIndex = 0
        expandedItemIndex = nil
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 125: // Down arrow
                selectedIndex = min(selectedIndex + 1, clipboard.history.count - 1)
                expandedItemIndex = nil
                return nil
            case 126: // Up arrow
                selectedIndex = max(selectedIndex - 1, 0)
                expandedItemIndex = nil
                return nil
            case 36: // Enter
                pasteItem(index: selectedIndex)
                return nil
            case 124: // Right arrow
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    expandedItemIndex = (expandedItemIndex == selectedIndex) ? nil : selectedIndex
                }
                return nil
            case 123: // Left arrow
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    expandedItemIndex = nil
                }
                return nil
            default:
                if let chars = event.charactersIgnoringModifiers, let number = Int(chars) {
                    let targetIndex = number == 0 ? 9 : number - 1
                    pasteItem(index: targetIndex)
                    return nil
                }
                return event
            }
        }
    }
    
    private func teardownKeyboardMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func pasteItem(index: Int) {
        guard index >= 0 && index < clipboard.history.count else { return }
        let item = clipboard.history[index]
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            shortcut.isExpanded = false
        }
        
        previousApp?.activate(options: .activateIgnoringOtherApps)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            clipboard.pasteItem(item)
        }
    }
}

// MARK: - ClipboardItemView
struct ClipboardItemView: View {
    let index: Int
    let item: ClipboardItem
    let isSelected: Bool
    let isExpanded: Bool
    let isDense: Bool
    let activeColor: Color
    let onPaste: () -> Void
    let onExpandToggle: () -> Void
    
    @State private var hover = false
    
    var body: some View {
        Button(action: onPaste) {
            HStack(spacing: 12) {
                let shortcutText = index == 9 ? "0" : (index < 9 ? "\(index + 1)" : "-")
                Text(shortcutText)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(activeColor)
                    .frame(width: 16, alignment: .leading)
                
                Text(item.text)
                    .lineLimit(isExpanded ? nil : 1)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
            }
            .padding(.vertical, isDense ? 6 : 10)
            .padding(.horizontal, 14)
            .background(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(activeColor.opacity(isSelected ? 0.8 : 0.0), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            hover = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

// MARK: - Native Drag View
struct NativeDragView: NSViewRepresentable {
    var onDragBegan: () -> Void
    var onDragEnded: () -> Void
    var onTap: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = DragTrackingView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? DragTrackingView {
            view.onDragBegan = onDragBegan
            view.onDragEnded = onDragEnded
            view.onTap = onTap
        }
    }
}

class DragTrackingView: NSView {
    var onDragBegan: (() -> Void)?
    var onDragEnded: (() -> Void)?
    var onTap: (() -> Void)?
    private var isDragging = false
    private var mouseDownLocation: NSPoint?
    private var windowStartOrigin: NSPoint?

    override var acceptsFirstResponder: Bool { true }
    
    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }
        mouseDownLocation = event.locationInWindow
        windowStartOrigin = window.frame.origin
        isDragging = false
        onDragBegan?()
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window, let startLocation = mouseDownLocation, let startOrigin = windowStartOrigin else { return }
        let currentLocation = event.locationInWindow
        let dx = currentLocation.x - startLocation.x
        let dy = currentLocation.y - startLocation.y
        
        // Threshold to distinguish click vs drag
        if abs(dx) > 3 || abs(dy) > 3 {
            isDragging = true
        }
        
        if isDragging {
            let screenRect = window.screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 10000, height: 10000)
            var newOrigin = NSPoint(x: window.frame.origin.x + dx, y: window.frame.origin.y + dy)
            newOrigin.x = max(screenRect.minX, min(newOrigin.x, screenRect.maxX - window.frame.width))
            newOrigin.y = max(screenRect.minY, min(newOrigin.y, screenRect.maxY - window.frame.height))
            window.setFrameOrigin(newOrigin)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if !isDragging {
            onTap?()
        } else {
            onDragEnded?()
        }
        isDragging = false
    }
}

// MARK: - Resize Edges View
struct ResizeEdgesView: View {
    @Binding var windowWidth: Double
    @Binding var windowHeight: Double
    @Binding var isResizing: Bool
    @Binding var resizeStartMouse: NSPoint?
    @Binding var resizeStartSize: NSSize?
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
                }
                guard let startMouse = resizeStartMouse, let startSize = resizeStartSize else { return }
                
                let currentMouse = NSEvent.mouseLocation
                let dx = currentMouse.x - startMouse.x
                let dy = currentMouse.y - startMouse.y
                
                switch edge {
                case .right:
                    windowWidth = max(280, startSize.width + dx)
                case .left:
                    windowWidth = max(280, startSize.width - dx)
                case .bottom:
                    windowHeight = max(300, startSize.height - dy) // y is inverted on screen vs window
                case .top:
                    windowHeight = max(300, startSize.height + dy)
                case .bottomRight:
                    windowWidth = max(280, startSize.width + dx)
                    windowHeight = max(300, startSize.height - dy)
                }
                
                adjustWindowFrame()
            }
            .onEnded { _ in
                isResizing = false
                resizeStartMouse = nil
                resizeStartSize = nil
                NSCursor.pop()
            }
    }
}


