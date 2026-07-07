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
    ("White", Color.primary),
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
    @AppStorage("themePreference") private var themePreference: String = "System"
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
        .onChange(of: themePreference) { _, newTheme in
            applyTheme(newTheme)
        }
        .onAppear {
            applyTheme(themePreference)
        }
    }
    
    private func applyTheme(_ theme: String) {
        if theme == "Light" {
            NSApp.appearance = NSAppearance(named: .aqua)
        } else if theme == "Dark" {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        } else {
            NSApp.appearance = nil
        }
        
        // Force appearance update on all windows instantly
        for window in NSApp.windows {
            window.appearance = NSApp.appearance
            window.viewsNeedDisplay = true
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
                    .foregroundColor(isEditMode ? Color.accentColor : .primary.opacity(0.6))
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
                    .foregroundColor(.primary.opacity(0.6))
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
            
            HStack(spacing: 4) {
                Image(systemName: "infinity")
                    .font(.system(size: 14, weight: .bold))
                Text("CopyM8")
                    .font(.system(size: 13, weight: .black, design: .rounded))
            }
            .foregroundColor(.primary)
                
            Spacer()
            
            // Spacing toggle
            HStack(spacing: 0) {
                Text(windowWidth < 360 ? "D..." : "Dense")
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .font(.system(size: 9, weight: isDense ? .bold : .regular))
                    .foregroundColor(isDense ? .primary : .primary.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(isDense ? Color.primary.opacity(0.15) : Color.clear)
                    .cornerRadius(4)
                    .onTapGesture { isDense = true }
                
                Text(windowWidth < 360 ? "S..." : "Spaced")
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .font(.system(size: 9, weight: !isDense ? .bold : .regular))
                    .foregroundColor(!isDense ? .primary : .primary.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(!isDense ? Color.primary.opacity(0.15) : Color.clear)
                    .cornerRadius(4)
                    .onTapGesture { isDense = false }
            }
            .background(Color.primary.opacity(0.05))
            .cornerRadius(4)
            
            // Colors moved to Settings
            
            // Settings Button
            Button(action: {
                showingSettings.toggle()
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundColor(.primary.opacity(0.6))
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
            
            Divider().frame(height: 12).background(Color.primary.opacity(0.2))
            
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
                    .foregroundColor(.primary.opacity(0.7))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(VisualEffectView(material: .windowBackground, blendingMode: .behindWindow))
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
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .offset(y: 10)
                }
            }, alignment: .top
        )
    }
    private var tabBarView: some View {
        HStack {
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
                                .foregroundColor(isActive ? Color.accentColor : .primary.opacity(0.6))
                                .background(
                                    isActive 
                                    ? (isBlack ? Color.primary.opacity(0.2) : activeColor.opacity(0.15)) 
                                    : Color.primary.opacity(0.05)
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
                .foregroundColor(.primary.opacity(0.3))
            Text(emptyStateMessage)
                .font(.system(size: 12))
                .foregroundColor(.primary.opacity(0.5))
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
                    .foregroundColor(.primary.opacity(0.6))
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
                    .foregroundColor(Color.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
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
                    .foregroundColor(selectedItemsForDeletion.isEmpty ? .primary.opacity(0.4) : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedItemsForDeletion.isEmpty ? Color.primary.opacity(0.1) : Color.red.opacity(0.8))
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
        .background(Color.primary.opacity(0.05))
    }
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.primary.opacity(0.5))
                .font(.system(size: 12))
            TextField("Search copied items or source apps...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.primary)
                .focused($isSearchFocused)
                .font(.system(size: 12))
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.primary.opacity(0.5))
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.05))
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
                        activeColor: activeColorName == "Black" ? .primary : activeColor,
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
                
                Spacer().frame(height: 4)
                
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
        .background(VisualEffectView(material: .windowBackground, blendingMode: .behindWindow))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
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
        let hoverLogoColor = activeColorName == "Black" ? Color.primary : activeColor
        let logoColor = isHovering ? hoverLogoColor : Color.primary.opacity(0.4)
        
        return RoundedRectangle(cornerRadius: 24)
            .fill(Color.clear)
            .background(VisualEffectView(material: .windowBackground, blendingMode: .behindWindow))
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
