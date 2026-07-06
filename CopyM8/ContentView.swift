import SwiftUI
import AppKit

enum DockEdge {
    case left, right, top
}

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

struct ContentView: View {
    @StateObject private var clipboard = ClipboardManager()
    @StateObject private var shortcut = ShortcutManager()
    @State private var isHovering = false
    @State private var showingClearAlert = false
    @State private var showingDeleteSelectedAlert = false
    @State private var showingEmptyToast = false
    @State private var expandedItemIndex: Int? = nil
    @State private var showingSettings = false
    @State private var draftHistoryCount: Int = 25
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    
    // Edit Mode State
    @State private var isEditMode: Bool = false
    @State private var selectedItemsForDeletion: Set<UUID> = []
    
    // Tab State
    @State private var activeTab: String = "All"
    
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
    
    private var filteredHistory: [ClipboardItem] {
        var results = clipboard.history
        
        switch activeTab {
        case "Pinned":
            results = results.filter { $0.isPinned }
        case "Text":
            results = results.filter { $0.itemType == .text }
        case "Links":
            results = results.filter { $0.itemType == .link }
        case "Images":
            results = results.filter { $0.itemType == .image }
        case "Files":
            results = results.filter { $0.itemType == .file }
        default:
            break
        }
        
        if !searchText.isEmpty {
            results = results.filter { item in
                item.text.localizedCaseInsensitiveContains(searchText) ||
                (item.sourceApp?.localizedCaseInsensitiveContains(searchText) == true)
            }
        }
        
        return results
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
    
    private func cycleColor() {
        if let idx = colors.firstIndex(where: { $0.name == activeColorName }) {
            let nextIdx = (idx + 1) % colors.count
            activeColorName = colors[nextIdx].name
        }
    }
    
    // MARK: - Body
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
                searchText = ""
                setupKeyboardMonitor()
            } else {
                teardownKeyboardMonitor()
            }
        }
        .onChange(of: maxHistoryCount) { _, newValue in
            clipboard.truncateHistory(to: newValue)
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
            expandedItemIndex = nil
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
            
            // Edit Mode Button
            Button(action: {
                withAnimation {
                    isEditMode.toggle()
                    if !isEditMode {
                        selectedItemsForDeletion.removeAll()
                    }
                }
            }) {
                Image(systemName: isEditMode ? "checkmark.circle.fill" : "checklist")
                    .font(.system(size: 11))
                    .foregroundColor(isEditMode ? activeColor : .white.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hover in
                if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() }
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
            
            Image(systemName: "infinity")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                
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
            
            // Colors moved to Settings
            
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
                SettingsView(draftHistoryCount: $draftHistoryCount, maxHistoryCount: $maxHistoryCount)
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
        .background(
            Group {
                Button("") { isSearchFocused = true }.keyboardShortcut("f", modifiers: .command)
                Button("") { isDense.toggle() }.keyboardShortcut("d", modifiers: .command)
                Button("") { cycleColor() }.keyboardShortcut("k", modifiers: .command)
                Button("") { showingSettings.toggle() }.keyboardShortcut(",", modifiers: .command)
                Button("") { 
                    withAnimation { 
                        isEditMode.toggle() 
                        if !isEditMode { selectedItemsForDeletion.removeAll() }
                    }
                }.keyboardShortcut("e", modifiers: .command)
            }
            .hidden()
        )
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
    private var tabBarView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(["All", "Pinned", "Text", "Links", "Images", "Files"], id: \.self) { tab in
                    if shouldShowTab(tab) {
                        Button(action: {
                            withAnimation {
                                activeTab = tab
                                selectedIndex = 0
                            }
                        }) {
                            let isBlack = activeColorName == "Black"
                            let isActive = activeTab == tab
                            
                            Text(tab)
                                .font(.system(size: 11, weight: isActive ? .bold : .regular))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .foregroundColor(isActive ? (isBlack ? .white : activeColor) : .white.opacity(0.6))
                                .background(
                                    isActive 
                                    ? (isBlack ? Color.white.opacity(0.2) : activeColor.opacity(0.15)) 
                                    : Color.white.opacity(0.05)
                                )
                                .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hover in
                            if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
    
    private func shouldShowTab(_ tab: String) -> Bool {
        switch tab {
        case "All", "Pinned": return true
        case "Text": return UserDefaults.standard.object(forKey: "saveText") as? Bool ?? true
        case "Links": return UserDefaults.standard.object(forKey: "saveLinks") as? Bool ?? true
        case "Images": return UserDefaults.standard.object(forKey: "saveImages") as? Bool ?? true
        case "Files": return UserDefaults.standard.object(forKey: "saveFiles") as? Bool ?? true
        default: return false
        }
    }

    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "No results found."
        } else if activeTab == "Pinned" {
            return "You don't have any pinned items.\nPin important items to keep them here!"
        } else {
            return "Your clipboard is empty.\nStart copying to see items here!"
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clipboard")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.3))
            Text(emptyStateMessage)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var editModeFooter: some View {
        HStack {
            Button(action: {
                if selectedItemsForDeletion.count == clipboard.history.count {
                    selectedItemsForDeletion.removeAll()
                } else {
                    selectedItemsForDeletion = Set(clipboard.history.map { $0.id })
                }
            }) {
                Text(selectedItemsForDeletion.count == clipboard.history.count ? "Deselect All" : "Select All")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hover in
                if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            
            Spacer()
            
            Button(action: {
                for id in selectedItemsForDeletion {
                    clipboard.togglePin(for: id)
                }
                selectedItemsForDeletion.removeAll()
                isEditMode = false
            }) {
                Text("Pin Selected")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(activeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(activeColor.opacity(0.1))
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hover in
                if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            
            Button(action: {
                if !selectedItemsForDeletion.isEmpty {
                    showingDeleteSelectedAlert = true
                }
            }) {
                Text("Delete Selected (\(selectedItemsForDeletion.count))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(selectedItemsForDeletion.isEmpty ? .white.opacity(0.4) : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedItemsForDeletion.isEmpty ? Color.white.opacity(0.1) : Color.red.opacity(0.8))
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(selectedItemsForDeletion.isEmpty)
            .onHover { hover in
                if !selectedItemsForDeletion.isEmpty {
                    if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
            .alert("Delete selected items?", isPresented: $showingDeleteSelectedAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    clipboard.history.removeAll { selectedItemsForDeletion.contains($0.id) }
                    selectedItemsForDeletion.removeAll()
                    isEditMode = false
                }
            } message: {
                Text("Are you sure you want to delete \(selectedItemsForDeletion.count) items? This action cannot be undone.")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.2))
    }
    
    private var searchBarView: some View {
        HStack {
            HStack(spacing: 4) {
                Text("CopyM8")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.trailing, 4)
            
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.5))
                .font(.system(size: 12))
            TextField("Search copied items or source apps...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.white)
                .focused($isSearchFocused)
                .font(.system(size: 12))
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
    }
    
    private var clipboardListView: some View {
        ScrollView {
            LazyVStack(spacing: isDense ? 2 : 12) {
                ForEach(Array(filteredHistory.enumerated()), id: \.element.id) { (index: Int, item: ClipboardItem) in
                    ClipboardItemView(
                        index: index,
                        item: item,
                        isSelected: index == selectedIndex && !isEditMode,
                        isExpanded: index == expandedItemIndex,
                        isDense: isDense,
                        activeColor: activeColorName == "Black" ? .white : activeColor,
                        isEditMode: isEditMode,
                        isChecked: selectedItemsForDeletion.contains(item.id),
                        onPaste: {
                            if isEditMode {
                                if selectedItemsForDeletion.contains(item.id) {
                                    selectedItemsForDeletion.remove(item.id)
                                } else {
                                    selectedItemsForDeletion.insert(item.id)
                                }
                            } else {
                                let isCmd = NSEvent.modifierFlags.contains(.command)
                                pasteItem(index: index, isFormatted: isCmd)
                            }
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
                    .contextMenu {
                        Button(item.isPinned ? "Unpin" : "Pin") {
                            clipboard.togglePin(for: item.id)
                        }
                        Button("Delete") {
                            clipboard.history.removeAll { $0.id == item.id }
                        }
                    }
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
                
                searchBarView
                tabBarView
                
                if filteredHistory.isEmpty {
                    emptyStateView
                } else {
                    clipboardListView
                }
                
                if isEditMode {
                    editModeFooter
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
        let width: CGFloat = isTop ? 40 : 28
        let height: CGFloat = isTop ? 28 : 40
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
        // Remove the min() clamp so the user has full manual control over the window height
        let calculatedHeight = windowHeight
        
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
            let width: CGFloat = isTop ? 40 : 28
            let height: CGFloat = isTop ? 28 : 40
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
        let pillWidth: CGFloat = isTop ? 40 : 28
        let pillHeight: CGFloat = isTop ? 28 : 40
        
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
            case 53: // Esc
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    shortcut.isExpanded = false
                }
                return nil
            case 125: // Down arrow
                let maxIndex = max(0, self.filteredHistory.count - 1)
                self.selectedIndex = min(self.selectedIndex + 1, maxIndex)
                self.expandedItemIndex = nil
                return nil

            case 35: // P
                if self.isEditMode {
                    if !self.selectedItemsForDeletion.isEmpty {
                        for id in self.selectedItemsForDeletion {
                            self.clipboard.togglePin(for: id)
                        }
                        self.selectedItemsForDeletion.removeAll()
                        withAnimation { self.isEditMode = false }
                    }
                } else if self.selectedIndex >= 0 && self.selectedIndex < self.filteredHistory.count {
                    let id = self.filteredHistory[self.selectedIndex].id
                    self.clipboard.togglePin(for: id)
                }
                return nil
            case 126: // Up arrow
                self.selectedIndex = max(self.selectedIndex - 1, 0)
                self.expandedItemIndex = nil
                return nil
            case 36: // Enter
                let isCmd = event.modifierFlags.contains(.command)
                self.pasteItem(index: self.selectedIndex, isFormatted: isCmd)
                return nil
            case 124: // Right arrow
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.expandedItemIndex = (self.expandedItemIndex == self.selectedIndex) ? nil : self.selectedIndex
                }
                return nil
            case 123: // Left arrow
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.expandedItemIndex = (self.expandedItemIndex == self.selectedIndex) ? nil : self.selectedIndex
                }
                return nil
            case 49: // Space
                if self.isEditMode {
                    if self.selectedIndex >= 0 && self.selectedIndex < self.filteredHistory.count {
                        let id = self.filteredHistory[self.selectedIndex].id
                        if self.selectedItemsForDeletion.contains(id) {
                            self.selectedItemsForDeletion.remove(id)
                        } else {
                            self.selectedItemsForDeletion.insert(id)
                        }
                    }
                    return nil
                }
                return event
            case 0: // A
                if event.modifierFlags.contains(.command) && self.isEditMode {
                    if self.selectedItemsForDeletion.count == self.filteredHistory.count {
                        self.selectedItemsForDeletion.removeAll()
                    } else {
                        self.selectedItemsForDeletion = Set(self.filteredHistory.map { $0.id })
                    }
                    return nil
                }
                return event
            default:
                if let chars = event.charactersIgnoringModifiers, let number = Int(chars) {
                    if event.modifierFlags.contains(.option) {
                        let tabs = ["All", "Pinned", "Text", "Links", "Images", "Files"]
                        let visibleTabs = tabs.filter { self.shouldShowTab($0) }
                        if number >= 1 && number <= visibleTabs.count {
                            withAnimation {
                                self.activeTab = visibleTabs[number - 1]
                                self.selectedIndex = 0
                            }
                        }
                        return nil
                    }
                    
                    let isCmd = event.modifierFlags.contains(.command)
                    let targetIndex = number == 0 ? 9 : number - 1
                    self.pasteItem(index: targetIndex, isFormatted: isCmd)
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
    
    private func pasteItem(index: Int, isFormatted: Bool = false) {
        if isEditMode { return }
        let history = self.filteredHistory
        guard index >= 0 && index < history.count else { return }
        let item = history[index]
        
        // 1. Set the clipboard immediately
        clipboard.prepareForPaste(item, isFormatted: isFormatted)
        
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
    let isEditMode: Bool
    let isChecked: Bool
    let onPaste: () -> Void
    let onExpandToggle: () -> Void
    
    @State private var hover = false
    
    var body: some View {
        Button(action: onPaste) {
            HStack(spacing: 12) {
                if isEditMode {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isChecked ? activeColor : .white.opacity(0.3))
                        .font(.system(size: 14))
                } else {
                    let shortcutText = index == 9 ? "0" : "\(index + 1)"
                    Text(shortcutText)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(activeColor)
                        .frame(width: 16, alignment: .leading)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if item.itemType == .image, let nsImage = LocalImageStore.shared.loadImage(id: item.id) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: isExpanded ? 200 : 40)
                            .cornerRadius(4)
                    } else if item.itemType == .file, let path = item.fileURL {
                        HStack(spacing: 6) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text(item.text)
                                .lineLimit(isExpanded ? nil : 1)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.95))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text(item.text)
                            .lineLimit(isExpanded ? nil : 1)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.95))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    if !isDense, let app = item.sourceApp {
                        Text("\(app) • \(item.timestamp.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                
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
struct SettingsView: View {
    @Binding var draftHistoryCount: Int
    @Binding var maxHistoryCount: Int
    
    @AppStorage("maxItemSizeMB") private var maxItemSizeMB: Int = 10
    @AppStorage("maxTotalStorageMB") private var maxTotalStorageMB: Int = 50
    
    @AppStorage("saveText") private var saveText: Bool = true
    @AppStorage("saveLinks") private var saveLinks: Bool = true
    @AppStorage("saveImages") private var saveImages: Bool = true
    @AppStorage("saveFiles") private var saveFiles: Bool = true
    
    @State private var selectedTab = "General"
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("General").tag("General")
                Text("Types").tag("Types")
                Text("Shortcuts").tag("Shortcuts")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            Divider()
            
            ScrollView {
                Group {
                    switch selectedTab {
                    case "General":
                        generalTab
                    case "Types":
                        typesTab
                    case "Shortcuts":
                        shortcutsTab
                    default:
                        EmptyView()
                    }
                }
                .padding()
            }
            .frame(height: 280)
        }
        .frame(width: 300)
    }
    
    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("History Limit:")
                    .font(.system(size: 13))
                Spacer()
                TextField("", value: $draftHistoryCount, format: .number)
                    .frame(width: 50)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        maxHistoryCount = max(5, draftHistoryCount)
                    }
                Stepper("", value: $draftHistoryCount, in: 5...500)
                    .labelsHidden()
            }
            Text("Maximum number of items to keep in history.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
            
            Divider()
            
            Text("Accent Color:")
                .font(.system(size: 13))
            
            HStack(spacing: 8) {
                ForEach(colors, id: \.name) { c in
                    Circle()
                        .fill(c.name == "Clear" ? Color.white.opacity(0.1) : c.color)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: UserDefaults.standard.string(forKey: "activeColorName") ?? "Ocean" == c.name ? 2 : 0)
                        )
                        .onTapGesture { 
                            UserDefaults.standard.set(c.name, forKey: "activeColorName") 
                        }
                }
            }
            
            Divider()
            
            HStack {
                Text("Max Item Size (MB):")
                    .font(.system(size: 13))
                Spacer()
                TextField("", value: $maxItemSizeMB, format: .number)
                    .frame(width: 50)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: maxItemSizeMB) { newValue in
                        if newValue > 20 { maxItemSizeMB = 20 }
                        else if newValue < 1 { maxItemSizeMB = 1 }
                    }
                Stepper("", value: $maxItemSizeMB, in: 1...20)
                    .labelsHidden()
            }
            
            HStack {
                Text("Total Storage Cap (MB):")
                    .font(.system(size: 13))
                Spacer()
                TextField("", value: $maxTotalStorageMB, format: .number)
                    .frame(width: 50)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: maxTotalStorageMB) { newValue in
                        if newValue > 100 { maxTotalStorageMB = 100 }
                        else if newValue < 1 { maxTotalStorageMB = 1 }
                    }
                Stepper("", value: $maxTotalStorageMB, in: 1...100)
                    .labelsHidden()
            }
            
            Spacer()
        }
    }
    
    private var typesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select which types of content to save.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
            
            Toggle("Save Text", isOn: $saveText)
            Toggle("Save Links", isOn: $saveLinks)
            Toggle("Save Images", isOn: $saveImages)
            Toggle("Save Files", isOn: $saveFiles)
            
            Spacer()
        }
    }
    
    private var shortcutsTab: some View {
        ScrollView {
            VStack(spacing: 8) {
                shortcutRow(action: "Open Search", key: "Cmd + F")
                shortcutRow(action: "Toggle Layout", key: "Cmd + D")
                shortcutRow(action: "Cycle Colors", key: "Cmd + K")
                shortcutRow(action: "Settings", key: "Cmd + ,")
                shortcutRow(action: "Edit Mode", key: "Cmd + E")
                shortcutRow(action: "Switch Tabs", key: "Opt + 1-6")
                shortcutRow(action: "Pin Item", key: "P")
                shortcutRow(action: "Select All (Edit)", key: "Cmd + A")
                shortcutRow(action: "Toggle Selection (Edit)", key: "Space")
                shortcutRow(action: "Close Window", key: "Esc")
            }
            .padding(.trailing, 12)
        }
    }
    
    private func shortcutRow(action: String, key: String) -> some View {
        HStack {
            Text(action).font(.system(size: 12))
            Spacer()
            Text(key)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
        }
    }
}
