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
    @State private var showingSettings = false
    @State private var draftHistoryCount: Int = 25
    
    // UI State
    @AppStorage("activeColorName") private var activeColorName: String = "Glacier"
    @AppStorage("isDense") private var isDense: Bool = true
    @AppStorage("dockEdgeRaw") private var dockEdgeRaw: String = "right"
    @AppStorage("windowWidth") private var windowWidth: Double = 320
    @AppStorage("windowHeight") private var windowHeight: Double = 420
    @AppStorage("maxHistoryCount") private var maxHistoryCount: Int = 25
    
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
        ("Bubblegum", Color(red: 0.9, green: 0.4, blue: 0.6)),
        ("White", Color.white),
        ("Grey", Color.gray),
        ("Black", Color.black)
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
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: shortcut.isExpanded)
        .onChange(of: shortcut.isExpanded) { _, expanded in
            adjustWindowFrame(expanded: expanded, animate: true)
            if expanded {
                previousApp = NSWorkspace.shared.frontmostApplication
                NSApp.activate()
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
                setupKeyboardMonitor()
            } else {
                teardownKeyboardMonitor()
            }
        }
        .onChange(of: maxHistoryCount) { _, newValue in
            clipboard.truncateHistory(to: newValue)
        }
    }
    
    private var headerView: some View {
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
                Text(windowWidth < 360 ? "D..." : "Dense")
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .font(.system(size: 9, weight: isDense ? .bold : .regular))
                    .foregroundColor(isDense ? .white : .white.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(isDense ? Color.white.opacity(0.15) : Color.clear)
                    .cornerRadius(4)
                    .onTapGesture { isDense = true }
                
                Text(windowWidth < 360 ? "S..." : "Spaced")
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
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
            HStack(spacing: windowWidth < 360 ? 4 : 6) {
                ForEach(colors, id: \.name) { c in
                    Circle()
                        .fill(c.name == "Clear" ? Color.white.opacity(0.1) : c.color)
                        .frame(width: windowWidth < 360 ? 8 : 10, height: windowWidth < 360 ? 8 : 10)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: activeColorName == c.name ? 2 : 0)
                        )
                        .onTapGesture { activeColorName = c.name }
                }
            }
            
            Divider().frame(height: 12).background(Color.white.opacity(0.2))
            
            // Settings Button
            Button(action: {
                showingSettings.toggle()
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hover in
                if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .popover(isPresented: $showingSettings, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Settings")
                        .font(.headline)
                    HStack {
                        Text("History Limit:")
                            .font(.system(size: 12))
                        TextField("", value: $draftHistoryCount, format: .number)
                            .frame(width: 40)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                maxHistoryCount = max(5, draftHistoryCount)
                                showingSettings = false
                            }
                        Stepper("", value: $draftHistoryCount, in: 5...500)
                            .labelsHidden()
                    }
                }
                .padding()
                .frame(width: 220)
            }
            .onChange(of: showingSettings) { _, isShowing in
                if isShowing {
                    draftHistoryCount = maxHistoryCount
                } else {
                    maxHistoryCount = max(5, draftHistoryCount)
                }
            }
            
            Divider().frame(height: 12).background(Color.white.opacity(0.2))
            
            // Reset Size Button
            Button(action: {
                withAnimation(.spring()) {
                    windowWidth = 340
                    windowHeight = 420
                    adjustWindowFrame(expanded: true, animate: true)
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
    }
    
    // MARK: - Expanded View
    private var emptyStateView: some View {
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
    }
    
    private var clipboardListView: some View {
        ScrollView {
            LazyVStack(spacing: isDense ? 2 : 12) {
                ForEach(Array(clipboard.history.enumerated()), id: \.element.id) { (index: Int, item: ClipboardItem) in
                    ClipboardItemView(
                        index: index,
                        item: item,
                        isSelected: index == selectedIndex,
                        isExpanded: index == expandedItemIndex,
                        isDense: isDense,
                        activeColor: activeColorName == "Black" ? .white : activeColor,
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

    private var expandedView: some View {
        ZStack {
            NativeDragView(
                onDragEnded: { snapToEdge() },
                onTap: {}
            )
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                if clipboard.history.isEmpty {
                    emptyStateView
                } else {
                    clipboardListView
                }
            }
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
        .overlay(
            ResizeEdgesView(
                windowWidth: $windowWidth,
                windowHeight: $windowHeight,
                isResizing: $isResizing,
                resizeStartMouse: $resizeStartMouse,
                resizeStartSize: $resizeStartSize,
                adjustWindowFrame: { adjustWindowFrame(expanded: true, animate: false) }
            )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Pill View
    private var pillView: some View {
        let isTop = dockEdge == .top
        let width: CGFloat = isTop ? 60 : 28
        let height: CGFloat = isTop ? 28 : 60
        let hoverLogoColor = activeColorName == "Black" ? Color.white : activeColor
        let logoColor = isHovering ? hoverLogoColor : Color.primary.opacity(0.4)
        
        return RoundedRectangle(cornerRadius: 24)
            .fill(Color.clear)
            .background(
                VisualEffectView(material: .popover, blendingMode: .behindWindow)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .frame(width: width, height: height)
            .overlay(
                ZStack {
                    // Glowing pill outline
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(logoColor, lineWidth: 2.5)
                        .shadow(color: isHovering ? logoColor.opacity(0.5) : .clear, radius: 3, x: 0, y: 0)
                    
                    // Infinity symbol in between
                    Image(systemName: "infinity")
                        .resizable()
                        .scaledToFit()
                        .font(Font.system(size: 10, weight: .medium))
                        .foregroundColor(logoColor)
                        .shadow(color: isHovering ? logoColor : .clear, radius: 4, x: 0, y: 0)
                        .opacity(isHovering ? 1.0 : 0.8)
                        .frame(width: 36, height: 16)
                        .frame(width: 60, height: 60) // Unclipped container before rotation
                        .rotationEffect(.degrees(isTop ? 0 : (dockEdge == .left ? -90 : 90)))
                }
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            .overlay(
                NativeDragView(
                    onDragEnded: { snapToEdge() },
                    onTap: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            shortcut.isExpanded = true
                        }
                    }
                )
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
        
        var finalWidth = max(340, windowWidth)
        var finalHeight = calculatedHeight
        if let screenRect = NSApp.windows.first?.screen?.visibleFrame {
            finalWidth = min(finalWidth, screenRect.width)
            finalHeight = min(finalHeight, screenRect.height)
        }
        
        return CGSize(width: finalWidth, height: finalHeight)
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
            let width: CGFloat = isTop ? 60 : 28
            let height: CGFloat = isTop ? 28 : 60
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
    
    private func adjustWindowFrame(expanded: Bool, animate: Bool = true) {
        guard let window = NSApp.windows.first else { return }
        
        let isTop = dockEdge == .top
        let pillWidth: CGFloat = isTop ? 60 : 28
        let pillHeight: CGFloat = isTop ? 28 : 60
        
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
        
        // Strictly constrain to screen bounds so macOS doesn't silently clamp and break relative math
        if let screenRect = window.screen?.visibleFrame {
            frame.origin.x = max(screenRect.minX, min(frame.origin.x, screenRect.maxX - frame.width))
            frame.origin.y = max(screenRect.minY, min(frame.origin.y, screenRect.maxY - frame.height))
        }
        
        window.setFrame(frame, display: true, animate: animate)
    }
    
    // MARK: - Keyboard Monitor
    @State private var eventMonitor: Any?
    @State private var previousApp: NSRunningApplication?
    
    private func setupKeyboardMonitor() {
        selectedIndex = 0
        expandedItemIndex = nil
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if showingSettings { return event }
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
        
        // 1. Set the clipboard immediately
        clipboard.prepareForPaste(item)
        
        // 2. Dismiss the window
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            shortcut.isExpanded = false
        }
        
        // 3. Reactivate the previous app
        previousApp?.activate(options: [])
        
        // 4. Wait for focus transfer, then trigger the paste keystroke
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            clipboard.triggerPasteKeystroke()
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
                let shortcutText = index == 9 ? "0" : "\(index + 1)"
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
                    onTap?()
                } else {
                    onDragEnded?()
                }
                
            default:
                break
            }
        }
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
                guard let startMouse = resizeStartMouse, let startSize = resizeStartSize,
                      let window = NSApp.windows.first, let screenRect = window.screen?.visibleFrame else { return }
                
                let currentMouse = NSEvent.mouseLocation
                let dx = currentMouse.x - startMouse.x
                let dy = currentMouse.y - startMouse.y
                
                let maxWidth = screenRect.width
                let maxHeight = screenRect.height
                
                switch edge {
                case .right:
                    windowWidth = min(maxWidth, max(340, startSize.width + dx))
                case .left:
                    windowWidth = min(maxWidth, max(340, startSize.width - dx))
                case .bottom:
                    windowHeight = min(maxHeight, max(300, startSize.height - dy)) // y is inverted on screen vs window
                case .top:
                    windowHeight = min(maxHeight, max(300, startSize.height + dy))
                case .bottomRight:
                    windowWidth = min(maxWidth, max(340, startSize.width + dx))
                    windowHeight = min(maxHeight, max(300, startSize.height - dy))
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


