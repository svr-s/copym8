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

extension UUID: Identifiable {
    public var id: UUID { self }
}

struct ContentView: View {
    @StateObject private var clipboard = ClipboardManager()
    @StateObject private var shortcut = ShortcutManager()
    @State private var isHovering = false
    @State private var showingDeleteSelectedAlert = false
    @State private var showingFolderDeleteAlert = false
    @State private var expandedItemIndex: Int? = nil
    @State private var showingSettings = false
    @State private var showingGroupAssignment = false
    @State private var itemToAssignGroup: UUID? = nil
    @State private var draftHistoryCount: Int = 25
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    
    @State private var isEditMode: Bool = false
    @State private var selectedItemsForDeletion: Set<UUID> = []
    
    @State private var activeTab: String = "All"
    @State private var selectedFolderId: UUID? = nil
    
    @AppStorage("activeColorName") private var activeColorName: String = "Glacier"
    @AppStorage("themePreference") private var themePreference: String = "System"
    @AppStorage("isDense") private var isDense: Bool = true
    @AppStorage("dockEdgeRaw") private var dockEdgeRaw: String = "right"
    @AppStorage("windowWidth") private var windowWidth: Double = 320
    @AppStorage("windowHeight") private var windowHeight: Double = 420
    @AppStorage("maxHistoryCount") private var maxHistoryCount: Int = 25
    
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
        case "Pinned": results = results.filter { $0.isPinned && $0.folderId == nil }
        case "Groups": 
            if let sfid = selectedFolderId {
                results = results.filter { $0.folderId == sfid }
            } else {
                return []
            }
        case "Text": results = results.filter { $0.itemType == .text }
        case "Links": results = results.filter { $0.itemType == .link }
        case "Images": results = results.filter { $0.itemType == .image }
        case "Files": results = results.filter { $0.itemType == .file }
        default: break
        }
        
        if !searchText.isEmpty {
            results = results.filter { item in
                item.text.localizedCaseInsensitiveContains(searchText) ||
                (item.sourceApp?.localizedCaseInsensitiveContains(searchText) == true)
            }
        }
        return results
    }
    
    @State private var dragOffset: CGSize = .zero
    @State private var initialWindowPosition: NSPoint? = nil
    
    @State private var selectedIndex: Int = 0
    @State private var isResizing = false
    @State private var resizeStartMouse: NSPoint?
    @State private var resizeStartSize: NSSize?
    
    @State private var isHoveringClose = false
    
    private func cycleColor() {
        if let idx = colors.firstIndex(where: { $0.name == activeColorName }) {
            activeColorName = colors[(idx + 1) % colors.count].name
        }
    }
    
    var body: some View {
        ZStack {
            if shortcut.isExpanded {
                ExpandedView(
                    isHoveringClose: $isHoveringClose,
                    isEditMode: $isEditMode,
                    selectedItemsForDeletion: $selectedItemsForDeletion,
                    isDense: $isDense,
                    windowWidth: $windowWidth,
                    windowHeight: $windowHeight,
                    showingSettings: $showingSettings,
                    draftHistoryCount: $draftHistoryCount,
                    maxHistoryCount: $maxHistoryCount,
                    activeTab: $activeTab,
                    selectedIndex: $selectedIndex,
                    activeColor: activeColor,
                    searchText: $searchText,
                    isSearchFocused: $isSearchFocused,
                    filteredHistory: filteredHistory,
                    expandedItemIndex: $expandedItemIndex,
                    activeColorName: activeColorName,
                    showingDeleteSelectedAlert: $showingDeleteSelectedAlert,
                    showingFolderDeleteAlert: $showingFolderDeleteAlert,
                    selectedFolderId: $selectedFolderId,
                    isResizing: $isResizing,
                    resizeStartMouse: $resizeStartMouse,
                    resizeStartSize: $resizeStartSize,
                    adjustWindowFrame: { adjustWindowFrame(expanded: true, animate: false) },
                    snapToEdge: snapToEdge,
                    pasteItem: pasteItem
                )
                .frame(width: windowWidth, height: windowHeight)
                .transition(.asymmetric(insertion: .opacity, removal: .opacity.animation(.easeOut(duration: 0.1))))
            } else {
                PillView(
                    dockEdge: dockEdge,
                    activeColorName: activeColorName,
                    activeColor: activeColor,
                    isHovering: $isHovering,
                    onExpanded: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            shortcut.isExpanded = true
                        }
                    },
                    snapToEdge: snapToEdge
                )
                .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: shortcut.isExpanded ? 12 : 24))
        .background(Color.clear)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: shortcut.isExpanded)
        .onChange(of: shortcut.isExpanded) { _, expanded in
            adjustWindowFrame(expanded: expanded, animate: true)
            if expanded {
                previousApp = NSWorkspace.shared.frontmostApplication
                NSApp.activate()
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
                searchText = ""
                activeTab = "All"
                selectedIndex = 0
                selectedFolderId = nil
                expandedItemIndex = nil
                setupKeyboardMonitor()
            } else {
                teardownKeyboardMonitor()
                itemToAssignGroup = nil
                showingSettings = false
                showingDeleteSelectedAlert = false
                showingFolderDeleteAlert = false
                showingGroupAssignment = false
            }
        }
        .onChange(of: activeTab) { _, _ in restartKeyboardMonitor() }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
            expandedItemIndex = nil
            restartKeyboardMonitor()
        }
        .onChange(of: selectedFolderId) { _, _ in restartKeyboardMonitor() }
        .onChange(of: maxHistoryCount) { _, newValue in clipboard.truncateHistory(to: newValue) }
        .onChange(of: themePreference) { _, newTheme in applyTheme(newTheme) }
        .onChange(of: clipboard.history) { _, _ in restartKeyboardMonitor() }
        .onAppear { applyTheme(themePreference) }
        .environmentObject(clipboard)
        .sheet(item: $itemToAssignGroup) { id in
            GroupAssignmentView(itemId: id)
                .environmentObject(clipboard)
        }
    }
    
    private func applyTheme(_ theme: String) {
        if theme == "Light" { NSApp.appearance = NSAppearance(named: .aqua) }
        else if theme == "Dark" { NSApp.appearance = NSAppearance(named: .darkAqua) }
        else { NSApp.appearance = nil }
        
        for window in NSApp.windows {
            window.appearance = NSApp.appearance
            window.viewsNeedDisplay = true
        }
    }
    
    private func getDynamicWindowSize() -> CGSize {
        let calculatedHeight = windowHeight
        var finalWidth = max(340, windowWidth)
        var finalHeight = calculatedHeight
        if let screenRect = NSApp.windows.first?.screen?.visibleFrame {
            finalWidth = min(finalWidth, screenRect.width)
            finalHeight = min(finalHeight, screenRect.height)
        }
        return CGSize(width: finalWidth, height: finalHeight)
    }
    
    private func snapToEdge() {
        guard let window = NSApp.windows.first, let screen = window.screen else { return }
        let screenRect = screen.visibleFrame
        let windowRect = window.frame
        let center = NSPoint(x: windowRect.midX, y: windowRect.midY)
        
        let distLeft = center.x - screenRect.minX
        let distRight = screenRect.maxX - center.x
        let distTop = screenRect.maxY - center.y
        let minEdge = min(distLeft, distRight, distTop)
        
        var targetX = windowRect.origin.x
        var targetY = windowRect.origin.y
        
        if minEdge == distLeft { dockEdgeRaw = "left"; targetX = screenRect.minX }
        else if minEdge == distRight { dockEdgeRaw = "right"; targetX = screenRect.maxX - windowRect.width }
        else { dockEdgeRaw = "top"; targetY = screenRect.maxY - windowRect.height }
        
        if !shortcut.isExpanded {
            let isTop = dockEdgeRaw == "top"
            let width: CGFloat = isTop ? 40 : 28
            let height: CGFloat = isTop ? 28 : 40
            window.setContentSize(NSSize(width: width, height: height))
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
    }
    
    @State private var eventMonitor: Any?
    @State private var previousApp: NSRunningApplication?
    
    private func setupKeyboardMonitor() {
        let _activeTab = self._activeTab
        let _selectedIndex = self._selectedIndex
        let _isEditMode = self._isEditMode
        let _selectedFolderId = self._selectedFolderId
        let _expandedItemIndex = self._expandedItemIndex
        let _selectedItemsForDeletion = self._selectedItemsForDeletion
        let _isSearchFocused = self._isSearchFocused
        let _itemToAssignGroup = self._itemToAssignGroup
        let _showingSettings = self._showingSettings
        let _showingDeleteSelectedAlert = self._showingDeleteSelectedAlert
        
        let clipboard = self.clipboard
        let pasteItem = self.pasteItem
        let moveSelectedFolder = self.moveSelectedFolder
        let moveSelectedItem = self.moveSelectedItem
        let getVisibleTabs = self.getVisibleTabs
        let _isDense = self._isDense
        let _activeColorName = self._activeColorName
        let _searchText = self._searchText
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if _showingSettings.wrappedValue || _showingDeleteSelectedAlert.wrappedValue || _itemToAssignGroup.wrappedValue != nil {
                if event.keyCode == 53 {
                    if _itemToAssignGroup.wrappedValue != nil { _itemToAssignGroup.wrappedValue = nil }
                    return event
                }
                return event
            }
            
            let activeTab = _activeTab.wrappedValue
            let selectedIndex = _selectedIndex.wrappedValue
            let isEditMode = _isEditMode.wrappedValue
            let selectedFolderId = _selectedFolderId.wrappedValue
            let expandedItemIndex = _expandedItemIndex.wrappedValue
            var selectedItemsForDeletion = _selectedItemsForDeletion.wrappedValue
            let isSearchFocused = _isSearchFocused.wrappedValue
            let searchText = _searchText.wrappedValue
            
            if event.modifierFlags.contains(.command) {
                switch event.keyCode {
                case 3: // F
                    _isSearchFocused.wrappedValue = true
                    return nil
                case 2: // D
                    _isDense.wrappedValue.toggle()
                    return nil
                case 43: // , (comma)
                    _showingSettings.wrappedValue.toggle()
                    return nil
                default: break
                }
            }
            
            let filteredHistory = clipboard.getFilteredHistory(activeTab: activeTab, selectedFolderId: selectedFolderId, searchText: searchText)
            
            if isSearchFocused {
                let allowedWhenSearchFocused: Set<UInt16> = [36, 48, 53, 125, 126] // Enter, Tab, Esc, Down, Up
                if !allowedWhenSearchFocused.contains(event.keyCode) {
                    return event
                }
            }
            
            if event.modifierFlags.contains(.option) {
                var newTab: String? = nil
                switch event.keyCode {
                case 35, 19: newTab = "Pinned" // P or 2
                case 5, 20: newTab = "Groups" // G or 3
                case 17, 21: newTab = "Text" // T or 4
                case 37, 23: newTab = "Links" // L or 5
                case 34, 22: newTab = "Images" // I or 6
                case 3, 26: newTab = "Files" // F or 7
                case 0, 18: newTab = "All" // A or 1
                default: break
                }
                
                if let tab = newTab, tab != activeTab {
                    withAnimation {
                        _activeTab.wrappedValue = tab
                        _selectedIndex.wrappedValue = 0
                        _expandedItemIndex.wrappedValue = nil
                    }
                    return nil
                }
            }
            
            switch event.keyCode {
            case 51: // Backspace
                if isEditMode {
                    if !selectedItemsForDeletion.isEmpty {
                        _showingDeleteSelectedAlert.wrappedValue = true
                    }
                } else {
                    if activeTab == "Groups" && selectedFolderId == nil {
                        // let other alert handle
                    } else if selectedIndex >= 0 && selectedIndex < filteredHistory.count {
                        let id = filteredHistory[selectedIndex].id
                        withAnimation { clipboard.history.removeAll { $0.id == id } }
                        _selectedIndex.wrappedValue = max(0, min(selectedIndex, filteredHistory.count - 2))
                    }
                }
                return nil
            case 125: // Down arrow
                if event.modifierFlags.contains(.command) {
                    if activeTab == "Groups" && selectedFolderId == nil {
                        moveSelectedFolder(false)
                    } else {
                        moveSelectedItem(false)
                    }
                    return nil
                }
                
                let maxIndex = (activeTab == "Groups" && selectedFolderId == nil) ? clipboard.folders.count - 1 : filteredHistory.count - 1
                if maxIndex >= 0 {
                    _selectedIndex.wrappedValue = (selectedIndex >= maxIndex) ? 0 : selectedIndex + 1
                }
                _expandedItemIndex.wrappedValue = nil
                return nil
            case 35: // P
                if isEditMode {
                    if !selectedItemsForDeletion.isEmpty {
                        for id in selectedItemsForDeletion { clipboard.togglePin(for: id) }
                        _selectedItemsForDeletion.wrappedValue.removeAll()
                        withAnimation { _isEditMode.wrappedValue = false }
                    }
                } else {
                    if selectedIndex >= 0 && selectedIndex < filteredHistory.count {
                        let id = filteredHistory[selectedIndex].id
                        clipboard.togglePin(for: id)
                    }
                }
                return nil
            case 5: // G
                if event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
                    if !isEditMode && selectedIndex >= 0 && selectedIndex < filteredHistory.count {
                        _itemToAssignGroup.wrappedValue = filteredHistory[selectedIndex].id
                    }
                    return nil
                }
                return event
            case 126: // Up arrow
                if event.modifierFlags.contains(.command) {
                    if activeTab == "Groups" && selectedFolderId == nil {
                        moveSelectedFolder(true)
                    } else {
                        moveSelectedItem(true)
                    }
                    return nil
                }
                
                let maxIndex = (activeTab == "Groups" && selectedFolderId == nil) ? clipboard.folders.count - 1 : filteredHistory.count - 1
                if maxIndex >= 0 {
                    _selectedIndex.wrappedValue = (selectedIndex <= 0) ? maxIndex : selectedIndex - 1
                }
                _expandedItemIndex.wrappedValue = nil
                return nil
            case 36: // Enter
                let isCmd = event.modifierFlags.contains(.command)
                pasteItem(selectedIndex, isCmd)
                return nil
            case 124: // Right arrow
                if activeTab == "Groups" && selectedFolderId == nil {
                    if selectedIndex >= 0 && selectedIndex < clipboard.folders.count {
                        withAnimation {
                            _selectedFolderId.wrappedValue = clipboard.folders[selectedIndex].id
                            _selectedIndex.wrappedValue = 0
                            _expandedItemIndex.wrappedValue = nil
                        }
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        _expandedItemIndex.wrappedValue = (expandedItemIndex == selectedIndex) ? nil : selectedIndex
                    }
                }
                return nil
            case 123: // Left arrow
                if activeTab == "Groups" {
                    if selectedFolderId == nil {
                        if selectedIndex >= 0 && selectedIndex < clipboard.folders.count {
                            withAnimation {
                                _selectedFolderId.wrappedValue = clipboard.folders[selectedIndex].id
                                _selectedIndex.wrappedValue = 0
                                _expandedItemIndex.wrappedValue = nil
                            }
                        }
                    } else {
                        withAnimation {
                            _selectedFolderId.wrappedValue = nil
                            _selectedIndex.wrappedValue = 0
                            _expandedItemIndex.wrappedValue = nil
                        }
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        _expandedItemIndex.wrappedValue = (expandedItemIndex == selectedIndex) ? nil : selectedIndex
                    }
                }
                return nil
            case 49: // Space
                if isEditMode {
                    if selectedIndex >= 0 && selectedIndex < filteredHistory.count {
                        let id = filteredHistory[selectedIndex].id
                        if selectedItemsForDeletion.contains(id) { _selectedItemsForDeletion.wrappedValue.remove(id) }
                        else { _selectedItemsForDeletion.wrappedValue.insert(id) }
                    }
                    return nil
                }
                return event
            case 14: // E
                if event.modifierFlags.contains(.command) {
                    withAnimation { _isEditMode.wrappedValue.toggle() }
                    return nil
                }
                return event
            case 0: // A
                if isEditMode && event.modifierFlags.contains(.command) {
                    if selectedItemsForDeletion.count == filteredHistory.count {
                        _selectedItemsForDeletion.wrappedValue.removeAll()
                    } else {
                        _selectedItemsForDeletion.wrappedValue = Set(filteredHistory.map { $0.id })
                    }
                    return nil
                }
                return event
            case 53: // Esc
                if isSearchFocused {
                    _isSearchFocused.wrappedValue = false
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { shortcut.isExpanded = false }
                }
                return nil
            case 48: // Tab
                if event.modifierFlags.contains(.option) {
                    let isShift = event.modifierFlags.contains(.shift)
                    let visibleTabs = getVisibleTabs()
                    if let currentIndex = visibleTabs.firstIndex(of: activeTab) {
                        let nextIndex = isShift 
                            ? (currentIndex - 1 + visibleTabs.count) % visibleTabs.count 
                            : (currentIndex + 1) % visibleTabs.count
                        withAnimation {
                            _activeTab.wrappedValue = visibleTabs[nextIndex]
                            _selectedIndex.wrappedValue = 0
                            _expandedItemIndex.wrappedValue = nil
                        }
                    }
                    return nil
                }
                return event
            default:
                if !isSearchFocused,
                   let char = event.charactersIgnoringModifiers,
                   let num = Int(char),
                   num >= 0 && num <= 9 {
                    
                    let targetIndex = num == 0 ? 9 : num - 1
                    if targetIndex < filteredHistory.count {
                        let isCmd = event.modifierFlags.contains(.command)
                        pasteItem(targetIndex, isCmd)
                        return nil
                    }
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
    
    private func restartKeyboardMonitor() {
        teardownKeyboardMonitor()
        if shortcut.isExpanded {
            setupKeyboardMonitor()
        }
    }
    
    private func pasteItem(index: Int, isFormatted: Bool = false) {
        if isEditMode { return }
        let history = self.filteredHistory
        guard index >= 0 && index < history.count else { return }
        let item = history[index]
        clipboard.prepareForPaste(item, isFormatted: isFormatted)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { shortcut.isExpanded = false }
        previousApp?.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { clipboard.triggerPasteKeystroke() }
    }
    
    private func getVisibleTabs() -> [String] {
        let tabs = ["All", "Pinned", "Groups", "Text", "Links", "Images", "Files"]
        return tabs.filter { t in
            switch t {
            case "All", "Pinned", "Groups": return true
            case "Text": return UserDefaults.standard.object(forKey: "saveText") as? Bool ?? true
            case "Links": return UserDefaults.standard.object(forKey: "saveLinks") as? Bool ?? true
            case "Images": return UserDefaults.standard.object(forKey: "saveImages") as? Bool ?? true
            case "Files": return UserDefaults.standard.object(forKey: "saveFiles") as? Bool ?? true
            default: return false
            }
        }
    }
    
    private func moveSelectedItem(up: Bool) {
        let history = filteredHistory
        guard selectedIndex >= 0 && selectedIndex < history.count else { return }
        
        let targetIndex = up ? selectedIndex - 1 : selectedIndex + 1
        guard targetIndex >= 0 && targetIndex < history.count else { return }
        
        let item1 = history[selectedIndex]
        let item2 = history[targetIndex]
        
        if let idx1 = clipboard.history.firstIndex(where: { $0.id == item1.id }),
           let idx2 = clipboard.history.firstIndex(where: { $0.id == item2.id }) {
            clipboard.history.swapAt(idx1, idx2)
            selectedIndex = targetIndex
        }
    }
    
    private func moveSelectedFolder(up: Bool) {
        guard selectedIndex >= 0 && selectedIndex < clipboard.folders.count else { return }
        let targetIndex = up ? selectedIndex - 1 : selectedIndex + 1
        guard targetIndex >= 0 && targetIndex < clipboard.folders.count else { return }
        
        clipboard.folders.swapAt(selectedIndex, targetIndex)
        selectedIndex = targetIndex
    }
}
