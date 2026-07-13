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



struct DisplayNode: Identifiable {
    let id: String
    let isFolder: Bool
    let folder: ClipboardFolder?
    let item: ClipboardItem?
    let parentFolderId: UUID?
    var isDivider: Bool = false
}

enum ReorderTarget: Equatable {
    case pinned
    case folders
    case items(folderId: UUID)
}

struct ContentView: View {
    @StateObject private var clipboard = ClipboardManager()
    @StateObject private var shortcut = ShortcutManager()
    @State private var isHovering = false
    @State private var showingDeleteSelectedAlert = false
    @State private var showingFolderDeleteAlert = false
    @State private var showingUngroupAlert = false
    @State private var expandedItemIndex: Int? = nil
    @State private var showingSettings = false
    @State private var showingGroupAssignment = false
    @State private var itemToAssignGroup: GroupAssignmentPayload? = nil
    @State private var draftHistoryCount: Int = 25
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    
    @State private var isEditMode: Bool = false
    @State private var selectedItemsForDeletion: Set<UUID> = []
    
    @State private var isReorderMode: Bool = false
    @State private var reorderTarget: ReorderTarget? = nil
    @State private var reorderFreezeLimit: String = "0"
    @State private var reorderBackupHistory: [ClipboardItem] = []
    @State private var reorderBackupFolders: [ClipboardFolder] = []
    @FocusState private var isFreezeFieldFocused: Bool
    
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
    
    @State private var expandedFolderIds: Set<UUID> = []
    
    private var displayNodes: [DisplayNode] {
        if isReorderMode {
            switch reorderTarget {
            case .folders:
                return clipboard.folders.map { DisplayNode(id: "folder_\($0.id.uuidString)", isFolder: true, folder: $0, item: nil, parentFolderId: nil) }
            case .items(let folderId):
                var items = clipboard.history.filter { $0.folderId == folderId }
                items.sort { item1, item2 in
                    if item1.orderIndex > 0 && item2.orderIndex > 0 { return item1.orderIndex < item2.orderIndex }
                    if item1.orderIndex > 0 { return true }
                    if item2.orderIndex > 0 { return false }
                    return item1.timestamp > item2.timestamp
                }
                var nodes: [DisplayNode] = []
                let freezeLimit = Int(reorderFreezeLimit) ?? 0
                for (i, item) in items.enumerated() {
                    if i == freezeLimit && freezeLimit > 0 {
                        nodes.append(DisplayNode(id: "divider_reorder", isFolder: false, folder: nil, item: nil, parentFolderId: folderId, isDivider: true))
                    }
                    nodes.append(DisplayNode(id: "item_\(item.id.uuidString)", isFolder: false, folder: nil, item: item, parentFolderId: folderId))
                }
                return nodes
            case .pinned:
                var items = clipboard.history.filter { $0.isPinned && $0.folderId == nil }
                items.sort { item1, item2 in
                    if item1.orderIndex > 0 && item2.orderIndex > 0 { return item1.orderIndex < item2.orderIndex }
                    if item1.orderIndex > 0 { return true }
                    if item2.orderIndex > 0 { return false }
                    return item1.timestamp > item2.timestamp
                }
                var nodes: [DisplayNode] = []
                let freezeLimit = Int(reorderFreezeLimit) ?? 0
                for (i, item) in items.enumerated() {
                    if i == freezeLimit && freezeLimit > 0 {
                        nodes.append(DisplayNode(id: "divider_reorder", isFolder: false, folder: nil, item: nil, parentFolderId: nil, isDivider: true))
                    }
                    nodes.append(DisplayNode(id: "item_\(item.id.uuidString)", isFolder: false, folder: nil, item: item, parentFolderId: nil))
                }
                return nodes
            case .none:
                return []
            }
        }
        
        if activeTab == "Groups" {
            let filteredFolders = clipboard.getFilteredFolders(searchText: searchText)
            var nodes: [DisplayNode] = []
            
            for folder in filteredFolders {
                nodes.append(DisplayNode(id: "folder_\(folder.id.uuidString)", isFolder: true, folder: folder, item: nil, parentFolderId: nil))
                
                if expandedFolderIds.contains(folder.id) {
                    var items = clipboard.history.filter { $0.folderId == folder.id }
                    if !searchText.isEmpty {
                        let bypassFilter = folder.name.localizedCaseInsensitiveContains(searchText)
                        if !bypassFilter {
                            items = items.filter { item in
                                if item.text.localizedCaseInsensitiveContains(searchText) { return true }
                                if item.sourceApp?.localizedCaseInsensitiveContains(searchText) == true { return true }
                                return false
                            }
                        }
                    }
                    
                    items.sort { item1, item2 in
                        if item1.orderIndex > 0 && item2.orderIndex > 0 { return item1.orderIndex < item2.orderIndex }
                        if item1.orderIndex > 0 { return true }
                        if item2.orderIndex > 0 { return false }
                        return item1.timestamp > item2.timestamp
                    }
                    
                    var addedDivider = false
                    let hasFrozen = items.contains(where: { $0.orderIndex > 0 })
                    for item in items {
                        if item.orderIndex == 0 && !addedDivider && hasFrozen {
                            nodes.append(DisplayNode(id: "divider_\(folder.id.uuidString)", isFolder: false, folder: nil, item: nil, parentFolderId: folder.id, isDivider: true))
                            addedDivider = true
                        }
                        nodes.append(DisplayNode(id: "item_\(item.id.uuidString)", isFolder: false, folder: nil, item: item, parentFolderId: folder.id))
                    }
                }
            }
            return nodes
        } else {
            // Re-use existing filteredHistory logic
            var results = clipboard.history
            
            switch activeTab {
            case "Pinned": results = results.filter { $0.isPinned && $0.folderId == nil }
            case "Text": results = results.filter { $0.itemType == .text }
            case "Links": results = results.filter { $0.itemType == .link }
            case "Images": results = results.filter { $0.itemType == .image }
            case "Files": results = results.filter { $0.itemType == .file }
            default: break
            }
            
            if !searchText.isEmpty {
                results = results.filter { item in
                    if item.text.localizedCaseInsensitiveContains(searchText) { return true }
                    if item.sourceApp?.localizedCaseInsensitiveContains(searchText) == true { return true }
                    if let folderId = item.folderId, let folder = clipboard.folders.first(where: { $0.id == folderId }) {
                        if folder.name.localizedCaseInsensitiveContains(searchText) { return true }
                    }
                    return false
                }
            }
            
            if activeTab == "Pinned" {
                results.sort { item1, item2 in
                    if item1.orderIndex > 0 && item2.orderIndex > 0 { return item1.orderIndex < item2.orderIndex }
                    if item1.orderIndex > 0 { return true }
                    if item2.orderIndex > 0 { return false }
                    return item1.timestamp > item2.timestamp
                }
                
                var nodes: [DisplayNode] = []
                var addedDivider = false
                let hasFrozen = results.contains(where: { $0.orderIndex > 0 })
                
                for item in results {
                    if item.orderIndex == 0 && !addedDivider && hasFrozen {
                        nodes.append(DisplayNode(id: "divider_pinned", isFolder: false, folder: nil, item: nil, parentFolderId: nil, isDivider: true))
                        addedDivider = true
                    }
                    nodes.append(DisplayNode(id: "item_\(item.id.uuidString)", isFolder: false, folder: nil, item: item, parentFolderId: nil))
                }
                return nodes
            }
            
            return results.map { DisplayNode(id: "item_\($0.id.uuidString)", isFolder: false, folder: nil, item: $0, parentFolderId: nil) }
        }
    }
    
    @State private var dragOffset: CGSize = .zero
    @State private var initialWindowPosition: NSPoint? = nil
    
    @State private var selectedIndex: Int = 0
    @State private var selectionAnchorIndex: Int? = nil
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
                    isReorderMode: $isReorderMode,
                    reorderTarget: $reorderTarget,
                    reorderFreezeLimit: $reorderFreezeLimit,
                    reorderBackupHistory: $reorderBackupHistory,
                    reorderBackupFolders: $reorderBackupFolders,
                    isFreezeFieldFocused: $isFreezeFieldFocused,
                    selectedIndex: $selectedIndex,
                    selectionAnchorIndex: $selectionAnchorIndex,
                    activeColor: activeColor,
                    searchText: $searchText,
                    isSearchFocused: $isSearchFocused,
                    displayNodes: displayNodes,
                    expandedFolderIds: $expandedFolderIds,
                    expandedItemIndex: $expandedItemIndex,
                    activeColorName: activeColorName,
                    showingDeleteSelectedAlert: $showingDeleteSelectedAlert,
                    showingFolderDeleteAlert: $showingFolderDeleteAlert,
                    showingUngroupAlert: $showingUngroupAlert,
                    itemToAssignGroup: $itemToAssignGroup,
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
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first(where: { $0 is CopyM8Window })?.makeKeyAndOrderFront(nil)
                searchText = ""
                activeTab = "All"
                selectedIndex = 0
                selectionAnchorIndex = nil
                expandedItemIndex = nil
                setupKeyboardMonitor()
            } else {
                teardownKeyboardMonitor()
                if isReorderMode {
                    clipboard.history = reorderBackupHistory
                    clipboard.folders = reorderBackupFolders
                    clipboard.isReordering = false
                    isReorderMode = false
                    reorderTarget = .none
                    activeTab = "All"
                }
                itemToAssignGroup = nil
                showingSettings = false
                showingDeleteSelectedAlert = false
                showingFolderDeleteAlert = false
                expandedFolderIds.removeAll()
                isEditMode = false
                selectedItemsForDeletion.removeAll()
            }
        }
        .onChange(of: activeTab) { _, _ in 
            restartKeyboardMonitor() 
            selectedItemsForDeletion.removeAll()
            selectionAnchorIndex = nil
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
            selectionAnchorIndex = nil
            expandedItemIndex = nil
            restartKeyboardMonitor()
        }
        .onChange(of: expandedFolderIds) { _, _ in restartKeyboardMonitor() }
        .onChange(of: maxHistoryCount) { _, newValue in clipboard.truncateHistory(to: newValue) }
        .onChange(of: themePreference) { _, newTheme in applyTheme(newTheme) }
        .onChange(of: clipboard.history) { _, _ in restartKeyboardMonitor() }
        .onChange(of: isEditMode) { _, editMode in 
            selectedItemsForDeletion.removeAll() 
            selectionAnchorIndex = nil
            if activeTab == "Groups" {
                if editMode {
                    expandedFolderIds = Set(clipboard.folders.map { $0.id })
                } else {
                    expandedFolderIds.removeAll()
                }
            }
        }
        .onChange(of: shortcut.requestedTab) { _, newTab in
            if let newTab = newTab {
                activeTab = newTab
                shortcut.requestedTab = nil
            }
        }
        .onAppear { applyTheme(themePreference) }
        .environmentObject(clipboard)
        .overlay(
            Group {
                if let payload = itemToAssignGroup {
                    ZStack {
                        Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                            .onTapGesture { itemToAssignGroup = nil }
                        GroupAssignmentView(
                            itemIds: payload.itemIds, 
                            onComplete: payload.onComplete,
                            onCancel: { itemToAssignGroup = nil }
                        )
                            .environmentObject(clipboard)
                            .frame(width: 280)
                            .padding(20)
                            .background(Color(NSColor.windowBackgroundColor))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                    }
                } else if showingUngroupAlert {
                    ZStack {
                        Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                            .onTapGesture { showingUngroupAlert = false }
                        UngroupConfirmationView(
                            onConfirm: ungroupSelectedItems,
                            onCancel: { showingUngroupAlert = false }
                        )
                            .frame(width: 280)
                            .padding(20)
                            .background(Color(NSColor.windowBackgroundColor))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                    }
                } else if showingDeleteSelectedAlert {
                    ZStack {
                        Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                            .onTapGesture { showingDeleteSelectedAlert = false }
                        DeleteConfirmationView(
                            isFolderDeletion: false,
                            itemCount: selectedItemsForDeletion.count,
                            onConfirm: { _ in deleteSelectedItems() },
                            onCancel: { showingDeleteSelectedAlert = false }
                        )
                        .frame(width: 280)
                        .padding(20)
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                    }
                } else if showingFolderDeleteAlert {
                    ZStack {
                        Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                            .onTapGesture { showingFolderDeleteAlert = false }
                        let folderIds = selectedItemsForDeletion.filter { id in clipboard.folders.contains(where: { $0.id == id }) }
                        DeleteConfirmationView(
                            isFolderDeletion: true,
                            itemCount: folderIds.count,
                            onConfirm: { keepItems in
                                if let keepItems = keepItems {
                                    deleteFolders(keepItems: keepItems)
                                }
                            },
                            onCancel: { showingFolderDeleteAlert = false }
                        )
                        .frame(width: 280)
                        .padding(20)
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                    }
                }
            }
        )
    }
    
    private func ungroupSelectedItems(pin: Bool) {
        for i in 0..<clipboard.history.count {
            if selectedItemsForDeletion.contains(clipboard.history[i].id) {
                clipboard.history[i].folderId = nil
                if pin {
                    clipboard.history[i].isPinned = true
                }
            }
        }
        selectedItemsForDeletion.removeAll()
        isEditMode = false
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
        if let screenRect = NSApp.windows.first(where: { $0 is CopyM8Window })?.screen?.visibleFrame {
            finalWidth = min(finalWidth, screenRect.width)
            finalHeight = min(finalHeight, screenRect.height)
        }
        return CGSize(width: finalWidth, height: finalHeight)
    }
    
    private func snapToEdge() {
        guard let window = NSApp.windows.first(where: { $0 is CopyM8Window }) ?? NSApp.windows.first, let screen = window.screen else { return }
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
                frame.origin.y -= (newSize.height - oldHeight)
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
    }
    
    @State private var eventMonitor: Any?
    @State private var previousApp: NSRunningApplication?
    
    private func setupKeyboardMonitor() {
        let _activeTab = self._activeTab
        let _selectedIndex = self._selectedIndex
        let _isEditMode = self._isEditMode
        let _expandedItemIndex = self._expandedItemIndex
        let _selectedItemsForDeletion = self._selectedItemsForDeletion
        let _isSearchFocused = self._isSearchFocused
        let _itemToAssignGroup = self._itemToAssignGroup
        let _showingSettings = self._showingSettings
        let _showingDeleteSelectedAlert = self._showingDeleteSelectedAlert
        let _showingFolderDeleteAlert = self._showingFolderDeleteAlert
        let _showingUngroupAlert = self._showingUngroupAlert
        
        let clipboard = self.clipboard
        let pasteItem = self.pasteItem
        let _isDense = self._isDense
        let _expandedFolderIds = self._expandedFolderIds
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if _showingSettings.wrappedValue || _showingDeleteSelectedAlert.wrappedValue || _showingFolderDeleteAlert.wrappedValue || _showingUngroupAlert.wrappedValue || _itemToAssignGroup.wrappedValue != nil {
                if event.keyCode == 53 {
                    if _itemToAssignGroup.wrappedValue != nil { _itemToAssignGroup.wrappedValue = nil }
                    return event
                }
                return event
            }
            
            let activeTab = _activeTab.wrappedValue
            let selectedIndex = _selectedIndex.wrappedValue
            let isEditMode = _isEditMode.wrappedValue
            let expandedItemIndex = _expandedItemIndex.wrappedValue
            let displayNodesLocal = self.displayNodes
            
            if event.modifierFlags.contains(.command) {
                switch event.keyCode {
                case 3: // F
                    if _isReorderMode.wrappedValue && (_reorderTarget.wrappedValue == .pinned || (activeTab == "Groups" && _reorderTarget.wrappedValue != .folders)) {
                        _isFreezeFieldFocused.wrappedValue = true
                    } else {
                        _isSearchFocused.wrappedValue = true
                    }
                    return nil
                case 15: // R
                    if activeTab == "Pinned" || activeTab == "Groups" {
                        if _isReorderMode.wrappedValue {
                            _isReorderMode.wrappedValue = false
                        } else {
                            _isEditMode.wrappedValue = false
                            clipboard.isReordering = true
                            _isReorderMode.wrappedValue = true
                            _reorderBackupHistory.wrappedValue = clipboard.history
                            _reorderBackupFolders.wrappedValue = clipboard.folders
                            
                            if activeTab == "Pinned" {
                                _reorderTarget.wrappedValue = .pinned
                                let pinned = clipboard.history.filter { $0.isPinned && $0.folderId == nil }
                                let frozenCount = pinned.filter { $0.orderIndex > 0 }.count
                                _reorderFreezeLimit.wrappedValue = "\(frozenCount)"
                            } else if activeTab == "Groups" {
                                if selectedIndex >= 0 && selectedIndex < displayNodesLocal.count {
                                    let node = displayNodesLocal[selectedIndex]
                                    if node.isFolder {
                                        _reorderTarget.wrappedValue = .folders
                                        _reorderFreezeLimit.wrappedValue = "0"
                                    } else if let fid = node.parentFolderId {
                                        _reorderTarget.wrappedValue = .items(folderId: fid)
                                        let items = clipboard.history.filter { $0.folderId == fid }
                                        let frozenCount = items.filter { $0.orderIndex > 0 }.count
                                        _reorderFreezeLimit.wrappedValue = "\(frozenCount)"
                                    }
                                } else {
                                    _reorderTarget.wrappedValue = .folders
                                    _reorderFreezeLimit.wrappedValue = "0"
                                }
                            }
                            _selectedItemsForDeletion.wrappedValue.removeAll()
                            _selectedIndex.wrappedValue = 0
                            _isReorderMode.wrappedValue = true
                        }
                    }
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
            
            if isSearchFocused {
                let allowedWhenSearchFocused: Set<UInt16> = [36, 48, 53, 125, 126, 123, 124]
                if !allowedWhenSearchFocused.contains(event.keyCode) {
                    return event
                }
            }
            
            if event.modifierFlags.contains(.option) && event.keyCode != 48 && event.keyCode != 123 {
                if _isReorderMode.wrappedValue { return nil }
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
            
            if let chars = event.charactersIgnoringModifiers, chars.count == 1 {
                let char = chars.uppercased()
                if _isReorderMode.wrappedValue && char == "F" && event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) {
                    _isFreezeFieldFocused.wrappedValue.toggle()
                    return nil
                }
                
                if activeTab == "Groups" && char >= "A" && char <= "Z" && !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.control) && !event.modifierFlags.contains(.option) {
                    let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                    if let letterIndex = alphabet.firstIndex(of: Character(char)) {
                        let folderIndex = alphabet.distance(from: alphabet.startIndex, to: letterIndex)
                        let folders = clipboard.folders
                        if folderIndex < folders.count {
                            let targetFolder = folders[folderIndex]
                            if let nodeIndex = displayNodesLocal.firstIndex(where: { $0.isFolder && $0.folder?.id == targetFolder.id }) {
                                withAnimation {
                                    _selectedIndex.wrappedValue = nodeIndex
                                    if !_expandedFolderIds.wrappedValue.contains(targetFolder.id) {
                                        _expandedFolderIds.wrappedValue.insert(targetFolder.id)
                                    } else {
                                        _expandedFolderIds.wrappedValue.remove(targetFolder.id)
                                    }
                                }
                                return nil
                            }
                        }
                    }
                }
            }
            
            switch event.keyCode {
            case 18...29:
                if _isFreezeFieldFocused.wrappedValue { return nil }
                let keyMap: [UInt16: Int] = [18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8, 29: 9]
                if let relativeIndex = keyMap[event.keyCode] {
                    let isCmd = event.modifierFlags.contains(.command)
                    if activeTab == "Groups" {
                        var targetFolderId: UUID? = nil
                        if selectedIndex >= 0 && selectedIndex < displayNodesLocal.count {
                            let selectedNode = displayNodesLocal[selectedIndex]
                            targetFolderId = selectedNode.isFolder ? selectedNode.folder?.id : selectedNode.parentFolderId
                        }
                        if let targetFolderId = targetFolderId {
                            let folderItemIndices = displayNodesLocal.indices.filter { displayNodesLocal[$0].parentFolderId == targetFolderId }
                            if relativeIndex < folderItemIndices.count {
                                pasteItem(folderItemIndices[relativeIndex], isCmd)
                            }
                        }
                    } else {
                        if relativeIndex < displayNodesLocal.count {
                            pasteItem(relativeIndex, isCmd)
                        }
                    }
                }
                return nil
            case 51: // Backspace
                if isEditMode {
                    if !_selectedItemsForDeletion.wrappedValue.isEmpty { _showingDeleteSelectedAlert.wrappedValue = true }
                } else if selectedIndex >= 0 && selectedIndex < displayNodesLocal.count {
                    if let id = displayNodesLocal[selectedIndex].item?.id {
                        if selectedIndex >= displayNodesLocal.count - 1 && selectedIndex > 0 { _selectedIndex.wrappedValue -= 1 }
                        withAnimation { clipboard.history.removeAll { $0.id == id } }
                    }
                }
                return nil
            case 35: // P
                if event.modifierFlags.contains(.command) {
                    if isEditMode {
                        if activeTab != "Pinned" {
                            for id in _selectedItemsForDeletion.wrappedValue {
                                if let idx = clipboard.history.firstIndex(where: { $0.id == id }) {
                                    clipboard.history[idx].isPinned = true
                                    clipboard.history[idx].folderId = nil
                                }
                            }
                            _selectedItemsForDeletion.wrappedValue.removeAll()
                            _isEditMode.wrappedValue = false
                        }
                    } else if selectedIndex >= 0 && selectedIndex < displayNodesLocal.count {
                        if let id = displayNodesLocal[selectedIndex].item?.id { clipboard.togglePin(for: id) }
                    }
                }
                return nil
            case 5: // G
                if event.modifierFlags.contains(.command) {
                    if isEditMode {
                        if !_selectedItemsForDeletion.wrappedValue.isEmpty {
                            _itemToAssignGroup.wrappedValue = GroupAssignmentPayload(itemIds: _selectedItemsForDeletion.wrappedValue) {
                                _selectedItemsForDeletion.wrappedValue.removeAll()
                                _isEditMode.wrappedValue = false
                            }
                        }
                    } else if selectedIndex >= 0 && selectedIndex < displayNodesLocal.count {
                        let node = displayNodesLocal[selectedIndex]
                        if !node.isFolder, let item = node.item {
                            _itemToAssignGroup.wrappedValue = GroupAssignmentPayload(itemIds: [item.id])
                        }
                    }
                }
                return nil
            case 32: // U
                if event.modifierFlags.contains(.command) {
                    if isEditMode {
                        if activeTab == "Pinned" {
                            for id in _selectedItemsForDeletion.wrappedValue {
                                if let idx = clipboard.history.firstIndex(where: { $0.id == id }) {
                                    clipboard.history[idx].isPinned = false
                                }
                            }
                            _selectedItemsForDeletion.wrappedValue.removeAll()
                            _isEditMode.wrappedValue = false
                        } else if activeTab == "Groups" {
                            let hasGroupedItem = clipboard.history.contains { item in _selectedItemsForDeletion.wrappedValue.contains(item.id) && item.folderId != nil }
                            if hasGroupedItem {
                                _showingUngroupAlert.wrappedValue = true
                            }
                        }
                    }
                }
                return nil
            case 126: // Up
                if _isFreezeFieldFocused.wrappedValue {
                    let current = Int(_reorderFreezeLimit.wrappedValue) ?? 0
                    if current < 10 { _reorderFreezeLimit.wrappedValue = "\(current + 1)" }
                    return nil
                }
                if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) && activeTab == "Groups" {
                    _expandedFolderIds.wrappedValue.removeAll()
                    return nil
                }
                if event.modifierFlags.contains(.command) && (activeTab == "Pinned" || activeTab == "Groups") {
                    var idsToMove: [(index: Int, id: UUID, isFolder: Bool)] = []
                    if _selectedItemsForDeletion.wrappedValue.isEmpty {
                        return nil

                    } else {
                        for (i, node) in displayNodesLocal.enumerated() {
                            if node.isFolder, let fid = node.folder?.id, _selectedItemsForDeletion.wrappedValue.contains(fid) {
                                idsToMove.append((i, fid, true))
                            } else if let iid = node.item?.id, _selectedItemsForDeletion.wrappedValue.contains(iid) {
                                idsToMove.append((i, iid, false))
                            }
                        }
                    }
                    
                    let folderIds = idsToMove.filter { $0.isFolder }.map { $0.id }
                    let itemIds = idsToMove.filter { !$0.isFolder }.map { $0.id }
                    if !folderIds.isEmpty { clipboard.moveFolders(up: true, ids: folderIds) }
                    if !itemIds.isEmpty { clipboard.moveItems(up: true, ids: itemIds) }
                    if selectedIndex > 0 { _selectedIndex.wrappedValue -= 1 }
                    return nil
                }
                
                let maxIndex = displayNodesLocal.count - 1
                if isEditMode || _isReorderMode.wrappedValue {
                    if event.modifierFlags.contains(.shift) {
                        if _selectionAnchorIndex.wrappedValue == nil { _selectionAnchorIndex.wrappedValue = selectedIndex }
                    } else {
                        _selectionAnchorIndex.wrappedValue = nil
                    }
                }
                if selectedIndex > 0 {
                    var nextIndex = selectedIndex - 1
                    if nextIndex > 0 && displayNodesLocal[nextIndex].isDivider { nextIndex -= 1 }
                    _selectedIndex.wrappedValue = nextIndex
                }
                else { _selectedIndex.wrappedValue = maxIndex }
                return nil
            case 125: // Down
                if _isFreezeFieldFocused.wrappedValue {
                    let current = Int(_reorderFreezeLimit.wrappedValue) ?? 0
                    if current > 0 { _reorderFreezeLimit.wrappedValue = "\(current - 1)" }
                    return nil
                }
                if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) && activeTab == "Groups" {
                    _expandedFolderIds.wrappedValue = Set(clipboard.folders.map { $0.id })
                    return nil
                }
                if event.modifierFlags.contains(.command) && (activeTab == "Pinned" || activeTab == "Groups") {
                    var idsToMove: [(index: Int, id: UUID, isFolder: Bool)] = []
                    if _selectedItemsForDeletion.wrappedValue.isEmpty {
                        return nil

                    } else {
                        for (i, node) in displayNodesLocal.enumerated() {
                            if node.isFolder, let fid = node.folder?.id, _selectedItemsForDeletion.wrappedValue.contains(fid) {
                                idsToMove.append((i, fid, true))
                            } else if let iid = node.item?.id, _selectedItemsForDeletion.wrappedValue.contains(iid) {
                                idsToMove.append((i, iid, false))
                            }
                        }
                    }
                    
                    let folderIds = idsToMove.filter { $0.isFolder }.map { $0.id }
                    let itemIds = idsToMove.filter { !$0.isFolder }.map { $0.id }
                    if !folderIds.isEmpty { clipboard.moveFolders(up: false, ids: folderIds) }
                    if !itemIds.isEmpty { clipboard.moveItems(up: false, ids: itemIds) }
                    if selectedIndex < displayNodesLocal.count - 1 { _selectedIndex.wrappedValue += 1 }
                    return nil
                }
                
                let maxIndex = displayNodesLocal.count - 1
                if isEditMode || _isReorderMode.wrappedValue {
                    if event.modifierFlags.contains(.shift) {
                        if _selectionAnchorIndex.wrappedValue == nil { _selectionAnchorIndex.wrappedValue = selectedIndex }
                    } else {
                        _selectionAnchorIndex.wrappedValue = nil
                    }
                }
                if selectedIndex < maxIndex {
                    var nextIndex = selectedIndex + 1
                    if nextIndex < maxIndex && displayNodesLocal[nextIndex].isDivider { nextIndex += 1 }
                    _selectedIndex.wrappedValue = nextIndex
                }
                else { _selectedIndex.wrappedValue = 0 }
                return nil
            case 36: // Enter
                if _isFreezeFieldFocused.wrappedValue {
                    _isFreezeFieldFocused.wrappedValue = false
                    return nil
                }
                if _isReorderMode.wrappedValue {
                    clipboard.isReordering = false
                    _isReorderMode.wrappedValue = false
                    
                    let freezeLimit = Int(_reorderFreezeLimit.wrappedValue) ?? 0
                    clipboard.applyReorder(target: _reorderTarget.wrappedValue, freezeLimit: freezeLimit)
                    
                    _reorderTarget.wrappedValue = .none
                    _selectedItemsForDeletion.wrappedValue.removeAll()
                    return nil
                }
                
                if selectedIndex >= 0 && selectedIndex < displayNodesLocal.count {
                    let node = displayNodesLocal[selectedIndex]
                    if node.isFolder, let folder = node.folder {
                        withAnimation {
                            if _expandedFolderIds.wrappedValue.contains(folder.id) { _expandedFolderIds.wrappedValue.remove(folder.id) }
                            else { _expandedFolderIds.wrappedValue.insert(folder.id) }
                        }
                    } else {
                        pasteItem(selectedIndex, event.modifierFlags.contains(.command))
                    }
                }
                return nil
            case 124: // Right
                if selectedIndex >= 0 && selectedIndex < displayNodesLocal.count {
                    let node = displayNodesLocal[selectedIndex]
                    if node.isFolder, let folder = node.folder {
                        withAnimation { _ = _expandedFolderIds.wrappedValue.insert(folder.id) }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { _expandedItemIndex.wrappedValue = selectedIndex }
                    }
                }
                return nil
            case 123: // Left
                if selectedIndex >= 0 && selectedIndex < displayNodesLocal.count {
                    let node = displayNodesLocal[selectedIndex]
                    if event.modifierFlags.contains(.option) {
                        if let parentId = node.parentFolderId ?? node.folder?.id {
                            withAnimation {
                                _expandedFolderIds.wrappedValue.remove(parentId)
                                if let pIdx = displayNodesLocal.firstIndex(where: { $0.folder?.id == parentId }) { _selectedIndex.wrappedValue = pIdx }
                                _expandedItemIndex.wrappedValue = nil
                            }
                        }
                        return nil
                    }
                    if node.isFolder, let folder = node.folder {
                        withAnimation { _ = _expandedFolderIds.wrappedValue.remove(folder.id) }
                    } else if expandedItemIndex == selectedIndex {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { _expandedItemIndex.wrappedValue = nil }
                    } else if activeTab == "Groups", let parentId = node.parentFolderId {
                        if let pIdx = displayNodesLocal.firstIndex(where: { $0.folder?.id == parentId }) {
                            withAnimation { _selectedIndex.wrappedValue = pIdx; _expandedItemIndex.wrappedValue = nil }
                        }
                    }
                }
                return nil
            case 49: // Space
                if (isEditMode || _isReorderMode.wrappedValue) && selectedIndex >= 0 && selectedIndex < displayNodesLocal.count {
                    if let anchor = _selectionAnchorIndex.wrappedValue {
                        let start = min(anchor, selectedIndex)
                        let end = max(anchor, selectedIndex)
                        
                        var idsToToggle: [UUID] = []
                        for i in start...end {
                            if i < displayNodesLocal.count {
                                if let id = displayNodesLocal[i].item?.id { idsToToggle.append(id) }
                                else if let id = displayNodesLocal[i].folder?.id { idsToToggle.append(id) }
                            }
                        }
                        
                        let allSelected = idsToToggle.allSatisfy { _selectedItemsForDeletion.wrappedValue.contains($0) }
                        withAnimation {
                            for id in idsToToggle {
                                if allSelected {
                                    _selectedItemsForDeletion.wrappedValue.remove(id)
                                } else {
                                    _selectedItemsForDeletion.wrappedValue.insert(id)
                                }
                            }
                            _selectionAnchorIndex.wrappedValue = nil
                        }
                    } else {
                        let node = displayNodesLocal[selectedIndex]
                        if let id = node.item?.id ?? node.folder?.id {
                            withAnimation {
                                if _selectedItemsForDeletion.wrappedValue.contains(id) { _selectedItemsForDeletion.wrappedValue.remove(id) }
                                else { _selectedItemsForDeletion.wrappedValue.insert(id) }
                            }
                        }
                    }
                    return nil
                }
                return event

            case 14: // E
                if event.modifierFlags.contains(.command) {
                    withAnimation {
                        _isEditMode.wrappedValue.toggle()
                        if _isEditMode.wrappedValue {
                            if _isReorderMode.wrappedValue {
                                clipboard.history = _reorderBackupHistory.wrappedValue
                                clipboard.folders = _reorderBackupFolders.wrappedValue
                                clipboard.isReordering = false
                                _isReorderMode.wrappedValue = false
                            }
                        } else {
                            _selectedItemsForDeletion.wrappedValue.removeAll()
                        }
                    }
                    return nil
                }
                return event
            case 0: // A
                if (isEditMode || _isReorderMode.wrappedValue) && event.modifierFlags.contains(.command) {
                    withAnimation {
                        let ids = Set(displayNodesLocal.compactMap { $0.item?.id ?? $0.folder?.id })
                        if _selectedItemsForDeletion.wrappedValue.isSuperset(of: ids) { _selectedItemsForDeletion.wrappedValue.subtract(ids) }
                        else { _selectedItemsForDeletion.wrappedValue.formUnion(ids) }
                    }
                    return nil
                }
                return event
            case 53: // Esc
                if _isFreezeFieldFocused.wrappedValue {
                    _isFreezeFieldFocused.wrappedValue = false
                    return nil
                }
                if isSearchFocused { _isSearchFocused.wrappedValue = false }
                else if _isReorderMode.wrappedValue {
                    clipboard.history = _reorderBackupHistory.wrappedValue
                    clipboard.folders = _reorderBackupFolders.wrappedValue
                    clipboard.isReordering = false
                    _isReorderMode.wrappedValue = false
                    _selectedItemsForDeletion.wrappedValue.removeAll()
                }
                else if isEditMode {
                    _isEditMode.wrappedValue = false
                    _selectedItemsForDeletion.wrappedValue.removeAll()
                }
                else { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { shortcut.isExpanded = false } }
                return nil
            case 48: // Tab
                if event.modifierFlags.contains(.option) {
                    if _isReorderMode.wrappedValue { return nil }
                    let isShift = event.modifierFlags.contains(.shift)
                    let visibleTabs = self.getVisibleTabs()
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
        if index >= 0 && index < displayNodes.count {
            if let item = displayNodes[index].item {
                clipboard.prepareForPaste(item, isFormatted: isFormatted)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { shortcut.isExpanded = false }
                previousApp?.activate(options: [])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { clipboard.triggerPasteKeystroke() }
            }
        }
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
        let nodes = displayNodes
        guard selectedIndex >= 0 && selectedIndex < nodes.count else { return }
        
        let targetIndex = up ? selectedIndex - 1 : selectedIndex + 1
        guard targetIndex >= 0 && targetIndex < nodes.count else { return }
        
        if let item1 = nodes[selectedIndex].item, let item2 = nodes[targetIndex].item {
            if let idx1 = clipboard.history.firstIndex(where: { $0.id == item1.id }),
               let idx2 = clipboard.history.firstIndex(where: { $0.id == item2.id }) {
                clipboard.history.swapAt(idx1, idx2)
                selectedIndex = targetIndex
            }
        }
    }
    
    private func moveSelectedFolder(up: Bool) {
        guard selectedIndex >= 0 && selectedIndex < clipboard.folders.count else { return }
        let targetIndex = up ? selectedIndex - 1 : selectedIndex + 1
        guard targetIndex >= 0 && targetIndex < clipboard.folders.count else { return }
        
        clipboard.folders.swapAt(selectedIndex, targetIndex)
        selectedIndex = targetIndex
    }
    
    private func deleteSelectedItems() {
        clipboard.history.removeAll { _selectedItemsForDeletion.wrappedValue.contains($0.id) }
        _selectedItemsForDeletion.wrappedValue.removeAll()
        _isEditMode.wrappedValue = false
    }
    
    private func deleteFolders(keepItems: Bool) {
        let folderIds = _selectedItemsForDeletion.wrappedValue.filter { id in clipboard.folders.contains(where: { $0.id == id }) }
        
        if keepItems {
            for i in 0..<clipboard.history.count {
                if let fId = clipboard.history[i].folderId, folderIds.contains(fId) {
                    clipboard.history[i].folderId = nil
                }
            }
        } else {
            clipboard.history.removeAll { item in
                if let fId = item.folderId { return folderIds.contains(fId) }
                return false
            }
        }
        
        clipboard.folders.removeAll { folderIds.contains($0.id) }
        
        let itemIds = _selectedItemsForDeletion.wrappedValue.subtracting(folderIds)
        if !itemIds.isEmpty {
            clipboard.history.removeAll { itemIds.contains($0.id) }
        }
        
        _selectedItemsForDeletion.wrappedValue.removeAll()
        _isEditMode.wrappedValue = false
    }
}
