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
    @StateObject var viewModel = ContentViewModel()
    @StateObject var clipboard = ClipboardManager()
    @StateObject var shortcut = ShortcutManager()
    @FocusState private var isSearchFocused: Bool
    
    
    @FocusState private var isFreezeFieldFocused: Bool
    
    
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
    
    
    private var displayNodes: [DisplayNode] {
        if viewModel.isReorderMode {
            switch viewModel.reorderTarget {
            case .folders:
                return clipboard.folders.filter { $0.id != cloudFolderId && $0.id != restoredFolderId }.map { DisplayNode(id: "folder_\($0.id.uuidString)", isFolder: true, folder: $0, item: nil, parentFolderId: nil) }
            case .items(let folderId):
                var items = clipboard.activeHistory.filter { !($0.isDeleted ?? false) && $0.folderId == folderId }
                items.sort { item1, item2 in
                    if item1.orderIndex > 0 && item2.orderIndex > 0 { return item1.orderIndex < item2.orderIndex }
                    if item1.orderIndex > 0 { return true }
                    if item2.orderIndex > 0 { return false }
                    return item1.timestamp > item2.timestamp
                }
                var nodes: [DisplayNode] = []
                let freezeLimit = Int(viewModel.reorderFreezeLimit) ?? 0
                for (i, item) in items.enumerated() {
                    if i == freezeLimit && freezeLimit > 0 {
                        nodes.append(DisplayNode(id: "divider_reorder", isFolder: false, folder: nil, item: nil, parentFolderId: folderId, isDivider: true))
                    }
                    nodes.append(DisplayNode(id: "item_\(item.id.uuidString)", isFolder: false, folder: nil, item: item, parentFolderId: folderId))
                }
                return nodes
            case .pinned:
                var items = clipboard.activeHistory.filter { !($0.isDeleted ?? false) && $0.isPinned && $0.folderId == nil }
                items.sort { item1, item2 in
                    if item1.orderIndex > 0 && item2.orderIndex > 0 { return item1.orderIndex < item2.orderIndex }
                    if item1.orderIndex > 0 { return true }
                    if item2.orderIndex > 0 { return false }
                    return item1.timestamp > item2.timestamp
                }
                var nodes: [DisplayNode] = []
                let freezeLimit = Int(viewModel.reorderFreezeLimit) ?? 0
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
        
        if viewModel.activeTab == "Trash" {
            var items = clipboard.history.filter { ($0.isDeleted ?? false) }
            
            if !viewModel.searchText.isEmpty {
                let searchLower = viewModel.searchText.lowercased()
                items = items.filter { item in
                    let contentMatch = item.text.lowercased().contains(searchLower)
                    let sourceMatch = item.sourceApp?.lowercased().contains(searchLower) ?? false
                    return contentMatch || sourceMatch
                }
            }
            
            items.sort { $0.deletedAt ?? Date() > $1.deletedAt ?? Date() }
            
            var nodes: [DisplayNode] = []
            for item in items {
                nodes.append(DisplayNode(id: "item_\(item.id.uuidString)", isFolder: false, folder: nil, item: item, parentFolderId: nil))
            }
            return nodes
        }
        
        if viewModel.activeTab == "Groups" {
            let filteredFolders = clipboard.getFilteredFolders(searchText: viewModel.searchText)
            var nodes: [DisplayNode] = []
            
            for folder in filteredFolders {
                nodes.append(DisplayNode(id: "folder_\(folder.id.uuidString)", isFolder: true, folder: folder, item: nil, parentFolderId: nil))
                
                if viewModel.expandedFolderIds.contains(folder.id) {
                    var items = clipboard.activeHistory.filter { !($0.isDeleted ?? false) && $0.folderId == folder.id }
                    if !viewModel.searchText.isEmpty {
                        let bypassFilter = folder.name.localizedCaseInsensitiveContains(viewModel.searchText)
                        if !bypassFilter {
                            items = items.filter { item in
                                if item.text.localizedCaseInsensitiveContains(viewModel.searchText) { return true }
                                if item.sourceApp?.localizedCaseInsensitiveContains(viewModel.searchText) == true { return true }
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
            var results = clipboard.activeHistory.filter { !($0.isDeleted ?? false) }
            
            switch viewModel.activeTab {
            case "Pinned": results = results.filter { $0.isPinned && $0.folderId == nil }
            case "Text": results = results.filter { $0.itemType == .text }
            case "Links": results = results.filter { $0.itemType == .link }
            case "Images": results = results.filter { $0.itemType == .image }
            case "Files": results = results.filter { $0.itemType == .file }
            default: break
            }
            
            if !viewModel.searchText.isEmpty {
                results = results.filter { item in
                    if item.text.localizedCaseInsensitiveContains(viewModel.searchText) { return true }
                    if item.sourceApp?.localizedCaseInsensitiveContains(viewModel.searchText) == true { return true }
                    if let folderId = item.folderId, let folder = clipboard.activeFolders.first(where: { $0.id == folderId }) {
                        if folder.name.localizedCaseInsensitiveContains(viewModel.searchText) { return true }
                    }
                    return false
                }
            }
            
            if viewModel.activeTab == "Pinned" {
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
    
    @State var dragOffset: CGSize = .zero
    @State var initialWindowPosition: NSPoint? = nil
    
    @State var isResizing = false
    @State var resizeStartMouse: NSPoint?
    @State var resizeStartSize: NSSize?
    
    @State var isHoveringClose = false
    
    private func cycleColor() {
        if let idx = colors.firstIndex(where: { $0.name == activeColorName }) {
            activeColorName = colors[(idx + 1) % colors.count].name
        }
    }
    
    @ViewBuilder
    private var modalsOverlay: some View {
        Group {
            if let payload = viewModel.itemToAssignGroup {
                ZStack {
                    Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                        .onTapGesture { viewModel.itemToAssignGroup = nil }
                    GroupAssignmentView(
                        itemIds: payload.itemIds, 
                        onComplete: payload.onComplete,
                        onCancel: { viewModel.itemToAssignGroup = nil }
                    )
                        .environmentObject(clipboard)
                        .frame(width: 280)
                        .padding(20)
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 8)
                }
            } else if viewModel.showingUngroupAlert {
                ZStack {
                    Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                        .onTapGesture { viewModel.showingUngroupAlert = false }
                    ActionConfirmationModalView(
                        title: "Ungroup selected items?",
                        message: "Do you want to keep these items in your Pinned list, or completely ungroup them?",
                        options: [
                            ModalOption(title: "Move to Pinned", icon: "pin.fill", isDestructive: false, action: { ungroupSelectedItems(pin: true); viewModel.showingUngroupAlert = false }),
                            ModalOption(title: "Completely Ungroup", icon: "folder.badge.minus", isDestructive: false, action: { ungroupSelectedItems(pin: false); viewModel.showingUngroupAlert = false }),
                            ModalOption(title: "Cancel", icon: "xmark", isDestructive: false, action: { viewModel.showingUngroupAlert = false })
                        ],
                        onCancel: { viewModel.showingUngroupAlert = false }
                    )
                        .frame(width: 280)
                        .padding(20)
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 8)
                }
            } else if viewModel.showingDeviceSwitcher {
                ZStack {
                    Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                        .onTapGesture { viewModel.showingDeviceSwitcher = false }
                    
                    let devices = ["Local (This Mac)"] + clipboard.availableDevices.filter { $0 != "Local (This Mac)" }
                    DeviceSwitcherView(
                        devices: devices,
                        onSelect: { selected in
                            clipboard.selectedDevice = selected
                            if selected != "Local (This Mac)" && viewModel.activeTab == "Trash" {
                                viewModel.activeTab = viewModel.previousTab == "Trash" ? "All" : viewModel.previousTab
                            }
                            viewModel.showingDeviceSwitcher = false
                        },
                        onCancel: { viewModel.showingDeviceSwitcher = false }
                    )
                        .frame(width: 280)
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 8)
                }
            } else if viewModel.showingEmptyTrashAlert {
                ZStack {
                    Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                        .onTapGesture { viewModel.showingEmptyTrashAlert = false }
                    let trashCount = clipboard.history.filter { ($0.isDeleted ?? false) }.count
                    ActionConfirmationModalView(
                        title: "Delete selected items?",
                        message: "Are you sure you want to delete \(trashCount) items? This action cannot be undone.",
                        options: [
                            ModalOption(title: "Delete \(trashCount) Item\(trashCount == 1 ? "" : "s")", icon: "trash.fill", isDestructive: true, action: {
                                clipboard.deleteItems(where: { ($0.isDeleted ?? false) }, hardDelete: true)
                                viewModel.showingEmptyTrashAlert = false
                            }),
                            ModalOption(title: "Cancel", icon: "xmark", isDestructive: false, action: { viewModel.showingEmptyTrashAlert = false })
                        ],
                        onCancel: { viewModel.showingEmptyTrashAlert = false }
                    )
                    .frame(width: 280)
                    .padding(20)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 8)
                }
            } else if viewModel.showingDeleteSelectedAlert {
                ZStack {
                    Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                        .onTapGesture { viewModel.showingDeleteSelectedAlert = false }
                    let count = viewModel.selectedItemsForDeletion.count
                    ActionConfirmationModalView(
                        title: "Delete selected items?",
                        message: "Are you sure you want to delete \(count) items? This action cannot be undone.",
                        options: [
                            ModalOption(title: "Delete \(count) Item\(count == 1 ? "" : "s")", icon: "trash.fill", isDestructive: true, action: { deleteSelectedItems(); viewModel.showingDeleteSelectedAlert = false }),
                            ModalOption(title: "Cancel", icon: "xmark", isDestructive: false, action: { viewModel.showingDeleteSelectedAlert = false })
                        ],
                        onCancel: { viewModel.showingDeleteSelectedAlert = false }
                    )
                    .frame(width: 280)
                    .padding(20)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 8)
                }
            } else if viewModel.showingFolderDeleteAlert {
                ZStack {
                    Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                        .onTapGesture { viewModel.showingFolderDeleteAlert = false }
                    let folderIds = viewModel.selectedItemsForDeletion.filter { id in clipboard.folders.contains(where: { $0.id == id }) }
                    ActionConfirmationModalView(
                        title: "Delete selected folders?",
                        message: "Do you want to keep the items inside the folders (move to Pinned) or delete them permanently?",
                        options: [
                            ModalOption(title: "Keep Items (Move to Pinned)", icon: "pin.fill", isDestructive: false, action: { deleteFolders(keepItems: true); viewModel.showingFolderDeleteAlert = false }),
                            ModalOption(title: "Delete All Permanently", icon: "trash.fill", isDestructive: true, action: { deleteFolders(keepItems: false); viewModel.showingFolderDeleteAlert = false }),
                            ModalOption(title: "Cancel", icon: "xmark", isDestructive: false, action: { viewModel.showingFolderDeleteAlert = false })
                        ],
                        onCancel: { viewModel.showingFolderDeleteAlert = false }
                    )
                    .frame(width: 280)
                    .padding(20)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 8)
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            if shortcut.isExpanded {
                ExpandedView(
                    isHoveringClose: $isHoveringClose,
                    isEditMode: $viewModel.isEditMode,
                    selectedItemsForDeletion: $viewModel.selectedItemsForDeletion,
                    isDense: $isDense,
                    windowWidth: $windowWidth,
                    windowHeight: $windowHeight,
                    draftHistoryCount: $viewModel.draftHistoryCount,
                    maxHistoryCount: $maxHistoryCount,
                    activeTab: $viewModel.activeTab,
                    previousTab: $viewModel.previousTab,
                    showingEmptyTrashAlert: $viewModel.showingEmptyTrashAlert,
                    isReorderMode: $viewModel.isReorderMode,
                    reorderTarget: $viewModel.reorderTarget,
                    reorderFreezeLimit: $viewModel.reorderFreezeLimit,
                    reorderBackupHistory: $viewModel.reorderBackupHistory,
                    reorderBackupFolders: $viewModel.reorderBackupFolders,
                    isFreezeFieldFocused: $isFreezeFieldFocused,
                    selectedIndex: $viewModel.selectedIndex,
                    selectionAnchorIndex: $viewModel.selectionAnchorIndex,
                    activeColor: activeColor,
                    searchText: $viewModel.searchText,
                    isSearchFocused: $isSearchFocused,
                    displayNodes: displayNodes,
                    expandedFolderIds: $viewModel.expandedFolderIds,
                    expandedItemIndex: $viewModel.expandedItemIndex,
                    editingFolderId: $viewModel.editingFolderId,
                    activeColorName: activeColorName,
                    showingDeleteSelectedAlert: $viewModel.showingDeleteSelectedAlert,
                    showingFolderDeleteAlert: $viewModel.showingFolderDeleteAlert,
                    showingUngroupAlert: $viewModel.showingUngroupAlert,
                    itemToAssignGroup: $viewModel.itemToAssignGroup,
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
                    isHovering: $viewModel.isHovering,
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
                viewModel.searchText = ""
                viewModel.activeTab = "All"
                viewModel.selectedIndex = 0
                viewModel.selectionAnchorIndex = nil
                viewModel.expandedItemIndex = nil
                setupKeyboardMonitor()
            } else {
                teardownKeyboardMonitor()
                if viewModel.isReorderMode {
                    clipboard.history = viewModel.reorderBackupHistory
                    clipboard.folders = viewModel.reorderBackupFolders
                    clipboard.isReordering = false
                    viewModel.isReorderMode = false
                    viewModel.reorderTarget = .none
                    viewModel.activeTab = "All"
                }
                viewModel.itemToAssignGroup = nil
                viewModel.showingDeviceSwitcher = false
                viewModel.showingDeleteSelectedAlert = false
                viewModel.showingFolderDeleteAlert = false
                viewModel.expandedFolderIds.removeAll()
                viewModel.isEditMode = false
                viewModel.selectedItemsForDeletion.removeAll()
            }
        }
        .onChange(of: viewModel.activeTab) { _, _ in 
            restartKeyboardMonitor() 
            viewModel.selectedItemsForDeletion.removeAll()
            viewModel.selectionAnchorIndex = nil
            viewModel.selectedIndex = 0
            viewModel.expandedItemIndex = nil
        }
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.selectedIndex = 0
            viewModel.selectionAnchorIndex = nil
            viewModel.expandedItemIndex = nil
            restartKeyboardMonitor()
        }
        .onChange(of: viewModel.expandedFolderIds) { _, _ in restartKeyboardMonitor() }
        .onChange(of: maxHistoryCount) { _, newValue in clipboard.truncateHistory(to: newValue) }
        .onChange(of: themePreference) { _, newTheme in applyTheme(newTheme) }
        .onChange(of: clipboard.history) { _, _ in restartKeyboardMonitor() }
        .onChange(of: viewModel.isEditMode) { _, editMode in 
            viewModel.selectedItemsForDeletion.removeAll() 
            viewModel.selectionAnchorIndex = nil
            if viewModel.activeTab == "Groups" {
                if editMode {
                    viewModel.expandedFolderIds = Set(clipboard.folders.map { $0.id })
                    viewModel.expandedFolderIds.insert(cloudFolderId)
                    viewModel.expandedFolderIds.insert(restoredFolderId)
                } else {
                    viewModel.expandedFolderIds.removeAll()
                }
            }
        }
        .onChange(of: shortcut.requestedTab) { _, newTab in
            if let newTab = newTab {
                viewModel.activeTab = newTab
                shortcut.requestedTab = nil
            }
        }
        .onAppear { applyTheme(themePreference) }
        .environmentObject(clipboard)
        .environmentObject(shortcut)
        .overlay(modalsOverlay)
        .overlay(
            Group {
                if viewModel.showingReadOnlyToast {
                    VStack {
                        Spacer()
                        Text("Action disabled while viewing a remote source")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                            .padding(.bottom, 24)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                } else if viewModel.showingImportSuccessToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text(viewModel.importSuccessMessage)
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ImportSuccessful"))) { notif in
            if let msg = notif.object as? String {
                viewModel.importSuccessMessage = msg
            } else {
                viewModel.importSuccessMessage = "Import successful"
            }
            if !viewModel.showingImportSuccessToast {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.showingImportSuccessToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.showingImportSuccessToast = false
                    }
                }
            }
        }
        .onChange(of: clipboard.selectedDevice) { _, _ in
            viewModel.selectedIndex = 0
            viewModel.selectionAnchorIndex = nil
            viewModel.expandedItemIndex = nil
        }
    }
    
    private func ungroupSelectedItems(pin: Bool) {
        for i in 0..<clipboard.history.count {
            if viewModel.selectedItemsForDeletion.contains(clipboard.history[i].id) {
                clipboard.setFolderId(for: [clipboard.history[i].id], folderId: nil)
                if pin {
                    clipboard.history[i].isPinned = true
                }
            }
        }
        viewModel.selectedItemsForDeletion.removeAll()
        viewModel.isEditMode = false
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
    
    @State var eventMonitor: Any?
    @State var previousApp: NSRunningApplication?
    

    
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
    
    private func pasteItem(index: Int, format: PasteFormatType = .plain) {
        if index >= 0 && index < displayNodes.count {
            if let item = displayNodes[index].item {
                clipboard.prepareForPaste(item, formatType: format)
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
        guard viewModel.selectedIndex >= 0 && viewModel.selectedIndex < nodes.count else { return }
        
        let targetIndex = up ? viewModel.selectedIndex - 1 : viewModel.selectedIndex + 1
        guard targetIndex >= 0 && targetIndex < nodes.count else { return }
        
        if let item1 = nodes[viewModel.selectedIndex].item, let item2 = nodes[targetIndex].item {
            if let idx1 = clipboard.history.firstIndex(where: { $0.id == item1.id }),
               let idx2 = clipboard.history.firstIndex(where: { $0.id == item2.id }) {
                clipboard.history.swapAt(idx1, idx2)
                viewModel.selectedIndex = targetIndex
            }
        }
    }
    
    private func moveSelectedFolder(up: Bool) {
        guard viewModel.selectedIndex >= 0 && viewModel.selectedIndex < clipboard.folders.count else { return }
        let targetIndex = up ? viewModel.selectedIndex - 1 : viewModel.selectedIndex + 1
        guard targetIndex >= 0 && targetIndex < clipboard.folders.count else { return }
        
        clipboard.folders.swapAt(viewModel.selectedIndex, targetIndex)
        viewModel.selectedIndex = targetIndex
    }
    
    private func deleteSelectedItems() {
        clipboard.deleteItems(where: { viewModel.selectedItemsForDeletion.contains($0.id) }, hardDelete: true)
        viewModel.selectedItemsForDeletion.removeAll()
        viewModel.isEditMode = false
    }
    
    private func deleteFolders(keepItems: Bool) {
        let folderIds = viewModel.selectedItemsForDeletion.filter { id in clipboard.folders.contains(where: { $0.id == id }) && id != cloudFolderId }
        let independentItemIds = viewModel.selectedItemsForDeletion.filter { id in !clipboard.folders.contains(where: { $0.id == id }) }
        
        if keepItems {
            for i in 0..<clipboard.history.count {
                if let fId = clipboard.history[i].folderId, folderIds.contains(fId) {
                    clipboard.setFolderId(for: [clipboard.history[i].id], folderId: nil)
                    clipboard.history[i].isPinned = true
                }
            }
        } else {
            clipboard.deleteItems(where: { item in
                if let fId = item.folderId { return folderIds.contains(fId) }
                return false
            }, hardDelete: true)
        }
        
        clipboard.folders.removeAll { folderIds.contains($0.id) }
        clipboard.deleteItems(where: { independentItemIds.contains($0.id) }, hardDelete: true)
        
        viewModel.selectedItemsForDeletion.removeAll()
        viewModel.isEditMode = false
    }
}



extension ContentView {
    private func setupKeyboardMonitor() {
        let _isSearchFocused = self._isSearchFocused
        
        let clipboard = self.clipboard
        let pasteItem = self.pasteItem
        let _isDense = self._isDense
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if SettingsWindowManager.shared.isSettingsOpen {
                return event
            }
            
            if viewModel.showingDeleteSelectedAlert || viewModel.showingFolderDeleteAlert || viewModel.showingUngroupAlert || viewModel.itemToAssignGroup != nil || viewModel.showingDeviceSwitcher || viewModel.showingEmptyTrashAlert {
                if event.keyCode == 53 {
                    if viewModel.itemToAssignGroup != nil { viewModel.itemToAssignGroup = nil }
                    if viewModel.showingDeviceSwitcher { viewModel.showingDeviceSwitcher = false }
                    return event
                }
                return event
            }
            
            // GATEKEEPER for remote sources
            if clipboard.selectedDevice != "Local (This Mac)" {
                let isDestructiveShortcut: Bool = {
                    if event.modifierFlags.contains(.command) {
                        return [5, 35, 32, 15].contains(event.keyCode) // G, P, U, R
                            || event.keyCode == 125 || event.keyCode == 126 // Cmd+Up/Down
                    }
                    if event.keyCode == 51 || event.keyCode == 117 { // Delete, Backspace
                        return true
                    }
                    return false
                }()
                
                if isDestructiveShortcut {
                    if !viewModel.showingReadOnlyToast {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.showingReadOnlyToast = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.showingReadOnlyToast = false
                            }
                        }
                    }
                    return nil
                }
            }
            
            let activeTab = viewModel.activeTab
            let isEditMode = viewModel.isEditMode
            let expandedItemIndex = viewModel.expandedItemIndex
            let displayNodesLocal = self.displayNodes
            
            if event.modifierFlags.contains(.command) {
                switch event.keyCode {
                case 3: // F
                    if viewModel.isReorderMode && (viewModel.reorderTarget == .pinned || (viewModel.activeTab == "Groups" && viewModel.reorderTarget != .folders)) {
                        _isFreezeFieldFocused.wrappedValue = true
                    } else {
                        _isSearchFocused.wrappedValue = true
                    }
                    return nil
                case 34: // I
                    if clipboard.selectedDevice != "Local (This Mac)" {
                        var itemsToImport: [ClipboardItem] = []
                        if viewModel.isEditMode {
                            itemsToImport = clipboard.history.filter { viewModel.selectedItemsForDeletion.contains($0.id) }
                            viewModel.selectedItemsForDeletion.removeAll()
                            viewModel.isEditMode = false
                        } else if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                            let node = displayNodesLocal[viewModel.selectedIndex]
                            if !node.isFolder, let item = node.item {
                                itemsToImport.append(item)
                            }
                        }
                        if !itemsToImport.isEmpty {
                            clipboard.importItems(itemsToImport)
                        }
                    }
                    return nil
                case 37: // L
                    _isDense.wrappedValue.toggle()
                    return nil
                case 2: // D
                    if event.modifierFlags.contains(.shift) {
                        if !clipboard.availableDevices.isEmpty {
                            viewModel.showingDeviceSwitcher = true
                        }
                        return nil
                    }
                    return event
                case 15: // R
                    if viewModel.activeTab == "Pinned" || viewModel.activeTab == "Groups" {
                        if viewModel.isReorderMode {
                            viewModel.isReorderMode = false
                        } else {
                            viewModel.isEditMode = false
                            clipboard.isReordering = true
                            viewModel.isReorderMode = true
                            viewModel.reorderBackupHistory = clipboard.history
                            viewModel.reorderBackupFolders = clipboard.folders
                            
                            if viewModel.activeTab == "Pinned" {
                                viewModel.reorderTarget = .pinned
                                let pinned = clipboard.history.filter { $0.isPinned && $0.folderId == nil }
                                let frozenCount = pinned.filter { $0.orderIndex > 0 }.count
                                viewModel.reorderFreezeLimit = "\(frozenCount)"
                            } else if viewModel.activeTab == "Groups" {
                                if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                                    let node = displayNodesLocal[viewModel.selectedIndex]
                                    if node.isFolder {
                                        viewModel.reorderTarget = .folders
                                        viewModel.reorderFreezeLimit = "0"
                                    } else if let fid = node.parentFolderId {
                                        viewModel.reorderTarget = .items(folderId: fid)
                                        let items = clipboard.history.filter { $0.folderId == fid }
                                        let frozenCount = items.filter { $0.orderIndex > 0 }.count
                                        viewModel.reorderFreezeLimit = "\(frozenCount)"
                                    }
                                } else {
                                    viewModel.reorderTarget = .folders
                                    viewModel.reorderFreezeLimit = "0"
                                }
                            }
                            viewModel.selectedIndex = 0
                            viewModel.isReorderMode = true
                        }
                    }
                    return nil
                case 17: // T
                    let isCmd = event.modifierFlags.contains(.command)
                    let isShift = event.modifierFlags.contains(.shift)
                    if isCmd && isShift {
                        if clipboard.selectedDevice == "Local (This Mac)" {
                            if viewModel.activeTab == "Trash" {
                                viewModel.activeTab = viewModel.previousTab
                            } else {
                                viewModel.previousTab = viewModel.activeTab
                                viewModel.activeTab = "Trash"
                            }
                        }
                        return nil
                    }
                    return nil
                case 6: // Z
                    let isCmd = event.modifierFlags.contains(.command)
                    let isShift = event.modifierFlags.contains(.shift)
                    if isCmd && !isShift && viewModel.activeTab == "Trash" {
                        if viewModel.isEditMode {
                            let ids = Array(viewModel.selectedItemsForDeletion)
                            if !ids.isEmpty {
                                clipboard.restoreItems(ids: ids)
                                viewModel.selectedItemsForDeletion.removeAll()
                                viewModel.isEditMode = false
                            }
                        } else {
                            if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                                let node = displayNodesLocal[viewModel.selectedIndex]
                                if let id = node.item?.id {
                                    if viewModel.selectedIndex > 0 && viewModel.selectedIndex == displayNodesLocal.count - 1 { viewModel.selectedIndex -= 1 }
                                    clipboard.restoreItems(ids: [id])
                                }
                            }
                        }
                        return nil
                    }
                    if !clipboard.history.isEmpty {
                        // Undo logic would go here if needed, but 'Cmd+Z' to restore single item in Trash Bin is handled within TrashBinView.
                    }
                    return nil
                default: break
                }
            }
            
            if isSearchFocused || viewModel.editingFolderId != nil {
                let allowedWhenFocused: Set<UInt16> = [36, 48, 53, 125, 126, 123, 124]
                if !allowedWhenFocused.contains(event.keyCode) {
                    return event
                }
            }
            
            if event.modifierFlags.contains(.option) && event.keyCode == 15 { // Option + R
                if viewModel.activeTab == "Groups" && !viewModel.isEditMode && !viewModel.isReorderMode {
                    if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                        let node = displayNodesLocal[viewModel.selectedIndex]
                        if node.isFolder, let folder = node.folder {
                            if folder.id != cloudFolderId {
                                viewModel.editingFolderId = folder.id
                            }
                            return nil
                        }
                    }
                }
            }
            
            if event.modifierFlags.contains(.option) && event.keyCode != 48 && event.keyCode != 123 && event.keyCode != 15 {
                if viewModel.isReorderMode { return nil }
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
                
                if let tab = newTab, tab != viewModel.activeTab {
                    withAnimation {
                        viewModel.activeTab = tab
                        viewModel.selectedIndex = 0
                        viewModel.expandedItemIndex = nil
                    }
                    return nil
                }
            }
            
            if let chars = event.charactersIgnoringModifiers, chars.count == 1 {
                let char = chars.uppercased()
                if viewModel.isReorderMode && char == "F" && event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) {
                    _isFreezeFieldFocused.wrappedValue.toggle()
                    return nil
                }
                
                if viewModel.activeTab == "Groups" && chars == "`" && !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.control) && !event.modifierFlags.contains(.option) {
                    if let nodeIndex = displayNodesLocal.firstIndex(where: { $0.isFolder && $0.folder?.id == UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }) {
                        withAnimation {
                            viewModel.selectedIndex = nodeIndex
                            if !viewModel.expandedFolderIds.contains(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!) {
                                viewModel.expandedFolderIds.insert(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
                            } else {
                                viewModel.expandedFolderIds.remove(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
                            }
                        }
                        return nil
                    }
                }

                if viewModel.activeTab == "Groups" && chars == "=" && !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.control) && !event.modifierFlags.contains(.option) {
                    if let nodeIndex = displayNodesLocal.firstIndex(where: { $0.isFolder && $0.folder?.id == restoredFolderId }) {
                        withAnimation {
                            viewModel.selectedIndex = nodeIndex
                            if !viewModel.expandedFolderIds.contains(restoredFolderId) {
                                viewModel.expandedFolderIds.insert(restoredFolderId)
                            } else {
                                viewModel.expandedFolderIds.remove(restoredFolderId)
                            }
                        }
                        return nil
                    }
                }
                
                if viewModel.activeTab == "Groups" && char >= "A" && char <= "Z" && !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.control) && !event.modifierFlags.contains(.option) {
                    let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                    if let letterIndex = alphabet.firstIndex(of: Character(char)) {
                        let folderIndex = alphabet.distance(from: alphabet.startIndex, to: letterIndex)
                        let standardFolders = clipboard.activeFolders.filter { $0.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }
                        if folderIndex < standardFolders.count {
                            let targetFolder = standardFolders[folderIndex]
                            if let nodeIndex = displayNodesLocal.firstIndex(where: { $0.isFolder && $0.folder?.id == targetFolder.id }) {
                                withAnimation {
                                    viewModel.selectedIndex = nodeIndex
                                    if !viewModel.expandedFolderIds.contains(targetFolder.id) {
                                        viewModel.expandedFolderIds.insert(targetFolder.id)
                                    } else {
                                        viewModel.expandedFolderIds.remove(targetFolder.id)
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
                if viewModel.activeTab == "Trash" { return event }
                let keyMap: [UInt16: Int] = [18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8, 29: 9]
                if let relativeIndex = keyMap[event.keyCode] {
                    let hasCmd = event.modifierFlags.contains(.command)
                    let hasCtrl = event.modifierFlags.contains(.control)
                    let format: PasteFormatType = (hasCmd && hasCtrl) ? .richNoLinks : (hasCmd ? .rich : .plain)
                    if viewModel.activeTab == "Groups" {
                        var targetFolderId: UUID? = nil
                        if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                            let selectedNode = displayNodesLocal[viewModel.selectedIndex]
                            targetFolderId = selectedNode.isFolder ? selectedNode.folder?.id : selectedNode.parentFolderId
                        }
                        if let targetFolderId = targetFolderId {
                            let folderItemIndices = displayNodesLocal.indices.filter { displayNodesLocal[$0].parentFolderId == targetFolderId }
                            if relativeIndex < folderItemIndices.count {
                                pasteItem(folderItemIndices[relativeIndex], format)
                            }
                        }
                    } else {
                        if relativeIndex < displayNodesLocal.count {
                            pasteItem(relativeIndex, format)
                        }
                    }
                }
                return nil
            case 51: // Backspace
                let isCmd = event.modifierFlags.contains(.command)
                let isShift = event.modifierFlags.contains(.shift)
                
                if viewModel.activeTab == "Trash" {
                    if isCmd && isShift {
                        let hasItems = clipboard.history.contains { $0.isDeleted ?? false }
                        if hasItems { viewModel.showingEmptyTrashAlert = true }
                        return nil
                    }
                    if viewModel.isEditMode {
                        if !viewModel.selectedItemsForDeletion.isEmpty {
                            viewModel.showingDeleteSelectedAlert = true
                        }
                    } else {
                        if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                            if let id = displayNodesLocal[viewModel.selectedIndex].item?.id ?? displayNodesLocal[viewModel.selectedIndex].folder?.id {
                                viewModel.selectedItemsForDeletion = [id]
                                viewModel.showingDeleteSelectedAlert = true
                            }
                        }
                    }
                    return nil
                }
                

                if viewModel.isEditMode {
                    let validDeletions = viewModel.selectedItemsForDeletion.filter { $0 != cloudFolderId && $0 != restoredFolderId }
                    if !validDeletions.isEmpty {
                        if isCmd {
                            // Hard Delete (with popup)
                            viewModel.selectedItemsForDeletion = validDeletions
                            let hasFoldersSelected = validDeletions.contains { id in clipboard.folders.contains(where: { $0.id == id }) }
                            if hasFoldersSelected {
                                viewModel.showingFolderDeleteAlert = true
                            } else {
                                viewModel.showingDeleteSelectedAlert = true
                            }
                        } else {
                            // Soft Delete (no popup)
                            let folderIds = validDeletions.filter { id in clipboard.folders.contains(where: { $0.id == id }) }
                            let independentItemIds = validDeletions.filter { !folderIds.contains($0) }
                            
                            clipboard.deleteItems(where: { item in
                                if let fId = item.folderId { return folderIds.contains(fId) }
                                return false
                            })
                            clipboard.folders.removeAll { folderIds.contains($0.id) }
                            clipboard.deleteItems(where: { independentItemIds.contains($0.id) })
                            
                            viewModel.selectedItemsForDeletion.removeAll()
                            viewModel.isEditMode = false
                        }
                    }
                } else if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                    let node = displayNodesLocal[viewModel.selectedIndex]
                    if node.isFolder, let folder = node.folder {
                        if folder.id != cloudFolderId && folder.id != restoredFolderId {
                            if isCmd {
                                viewModel.selectedItemsForDeletion = [folder.id]
                                viewModel.showingFolderDeleteAlert = true
                            } else {
                                clipboard.deleteItems(where: { $0.folderId == folder.id })
                                clipboard.folders.removeAll(where: { $0.id == folder.id })
                                if viewModel.selectedIndex >= displayNodesLocal.count - 1 && viewModel.selectedIndex > 0 { viewModel.selectedIndex -= 1 }
                            }
                        }
                    } else if let id = node.item?.id {
                        if isCmd {
                            viewModel.selectedItemsForDeletion = [id]
                            viewModel.showingDeleteSelectedAlert = true
                        } else {
                            if viewModel.selectedIndex >= displayNodesLocal.count - 1 && viewModel.selectedIndex > 0 { viewModel.selectedIndex -= 1 }
                            withAnimation { clipboard.deleteItems(where: { $0.id == id }) }
                        }
                    }
                }
                return nil
            case 35: // P
                if event.modifierFlags.contains(.command) {
                    if viewModel.activeTab == "Trash" { return nil }
                    if viewModel.isEditMode {
                        if viewModel.activeTab != "Pinned" {
                            for id in viewModel.selectedItemsForDeletion {
                                if let idx = clipboard.history.firstIndex(where: { $0.id == id }) {
                                    clipboard.history[idx].isPinned = true
                                    clipboard.setFolderId(for: [id], folderId: nil)
                                }
                            }
                            viewModel.selectedItemsForDeletion.removeAll()
                            viewModel.isEditMode = false
                        }
                    } else if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                        if let id = displayNodesLocal[viewModel.selectedIndex].item?.id { clipboard.togglePin(for: id) }
                    }
                }
                return nil
            case 5: // G
                if event.modifierFlags.contains(.command) {
                    if viewModel.activeTab == "Trash" { return nil }
                    if viewModel.isEditMode {
                        if !viewModel.selectedItemsForDeletion.isEmpty {
                            viewModel.itemToAssignGroup = GroupAssignmentPayload(itemIds: viewModel.selectedItemsForDeletion) {
                                viewModel.selectedItemsForDeletion.removeAll()
                                viewModel.isEditMode = false
                            }
                        }
                    } else if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                        let node = displayNodesLocal[viewModel.selectedIndex]
                        if !node.isFolder, let item = node.item {
                            viewModel.itemToAssignGroup = GroupAssignmentPayload(itemIds: [item.id])
                        }
                    }
                }
                return nil
            case 32: // U
                if event.modifierFlags.contains(.command) {
                    if viewModel.activeTab == "Trash" { return nil }
                    if viewModel.isEditMode {
                        if viewModel.activeTab == "Pinned" {
                            for id in viewModel.selectedItemsForDeletion {
                                if let idx = clipboard.history.firstIndex(where: { $0.id == id }) {
                                    clipboard.history[idx].isPinned = false
                                }
                            }
                            viewModel.selectedItemsForDeletion.removeAll()
                            viewModel.isEditMode = false
                        } else if viewModel.activeTab == "Groups" {
                            let hasGroupedItem = clipboard.history.contains { item in viewModel.selectedItemsForDeletion.contains(item.id) && item.folderId != nil }
                            if hasGroupedItem {
                                viewModel.showingUngroupAlert = true
                            }
                        }
                    } else if viewModel.activeTab == "Groups" && viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                        let node = displayNodesLocal[viewModel.selectedIndex]
                        if !node.isFolder, let item = node.item, item.folderId != nil {
                            viewModel.selectedItemsForDeletion = [item.id]
                            viewModel.showingUngroupAlert = true
                        }
                    }
                }
                return nil
            case 126: // Up
                if viewModel.editingFolderId != nil { return event }
                if _isFreezeFieldFocused.wrappedValue {
                    let current = Int(viewModel.reorderFreezeLimit) ?? 0
                    if current < 10 { viewModel.reorderFreezeLimit = "\(current + 1)" }
                    return nil
                }
                if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) && viewModel.activeTab == "Groups" {
                    viewModel.expandedFolderIds.removeAll()
                    return nil
                }
                if viewModel.isReorderMode && event.modifierFlags.contains(.command) && (viewModel.activeTab == "Pinned" || viewModel.activeTab == "Groups") {
                    var idsToMove: [(index: Int, id: UUID, isFolder: Bool)] = []
                    if viewModel.selectedItemsForDeletion.isEmpty {
                        return nil

                    } else {
                        for (i, node) in displayNodesLocal.enumerated() {
                            if node.isFolder, let fid = node.folder?.id, viewModel.selectedItemsForDeletion.contains(fid) {
                                idsToMove.append((i, fid, true))
                            } else if let iid = node.item?.id, viewModel.selectedItemsForDeletion.contains(iid) {
                                idsToMove.append((i, iid, false))
                            }
                        }
                    }
                    
                    let folderIds = idsToMove.filter { $0.isFolder }.map { $0.id }
                    let itemIds = idsToMove.filter { !$0.isFolder }.map { $0.id }
                    if !folderIds.isEmpty { clipboard.moveFolders(up: true, ids: folderIds) }
                    if !itemIds.isEmpty { clipboard.moveItems(up: true, ids: itemIds) }
                    if viewModel.selectedIndex > 0 { viewModel.selectedIndex -= 1 }
                    return nil
                }
                
                let maxIndex = displayNodesLocal.count - 1
                if viewModel.isEditMode || viewModel.isReorderMode {
                    if event.modifierFlags.contains(.shift) {
                        if viewModel.selectionAnchorIndex == nil { viewModel.selectionAnchorIndex = viewModel.selectedIndex }
                    } else {
                        viewModel.selectionAnchorIndex = nil
                    }
                }
                if viewModel.selectedIndex > 0 {
                    var nextIndex = viewModel.selectedIndex - 1
                    if nextIndex > 0 && displayNodesLocal[nextIndex].isDivider { nextIndex -= 1 }
                    viewModel.selectedIndex = nextIndex
                }
                else { viewModel.selectedIndex = maxIndex }
                return nil
            case 125: // Down
                if viewModel.editingFolderId != nil { return event }
                if _isFreezeFieldFocused.wrappedValue {
                    let current = Int(viewModel.reorderFreezeLimit) ?? 0
                    if current > 0 { viewModel.reorderFreezeLimit = "\(current - 1)" }
                    return nil
                }
                if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) && viewModel.activeTab == "Groups" {
                    viewModel.expandedFolderIds = Set(clipboard.folders.map { $0.id })
                    return nil
                }
                if viewModel.isReorderMode && event.modifierFlags.contains(.command) && (viewModel.activeTab == "Pinned" || viewModel.activeTab == "Groups") {
                    var idsToMove: [(index: Int, id: UUID, isFolder: Bool)] = []
                    if viewModel.selectedItemsForDeletion.isEmpty {
                        return nil

                    } else {
                        for (i, node) in displayNodesLocal.enumerated() {
                            if node.isFolder, let fid = node.folder?.id, viewModel.selectedItemsForDeletion.contains(fid) {
                                idsToMove.append((i, fid, true))
                            } else if let iid = node.item?.id, viewModel.selectedItemsForDeletion.contains(iid) {
                                idsToMove.append((i, iid, false))
                            }
                        }
                    }
                    
                    let folderIds = idsToMove.filter { $0.isFolder }.map { $0.id }
                    let itemIds = idsToMove.filter { !$0.isFolder }.map { $0.id }
                    if !folderIds.isEmpty { clipboard.moveFolders(up: false, ids: folderIds) }
                    if !itemIds.isEmpty { clipboard.moveItems(up: false, ids: itemIds) }
                    if viewModel.selectedIndex < displayNodesLocal.count - 1 { viewModel.selectedIndex += 1 }
                    return nil
                }
                
                let maxIndex = displayNodesLocal.count - 1
                if viewModel.isEditMode || viewModel.isReorderMode {
                    if event.modifierFlags.contains(.shift) {
                        if viewModel.selectionAnchorIndex == nil { viewModel.selectionAnchorIndex = viewModel.selectedIndex }
                    } else {
                        viewModel.selectionAnchorIndex = nil
                    }
                }
                if viewModel.selectedIndex < maxIndex {
                    var nextIndex = viewModel.selectedIndex + 1
                    if nextIndex < maxIndex && displayNodesLocal[nextIndex].isDivider { nextIndex += 1 }
                    viewModel.selectedIndex = nextIndex
                }
                else { viewModel.selectedIndex = 0 }
                return nil
            case 36: // Enter
                if viewModel.activeTab == "Trash" {
                    return nil
                }
                if _isFreezeFieldFocused.wrappedValue {
                    _isFreezeFieldFocused.wrappedValue = false
                    return nil
                }
                if viewModel.editingFolderId != nil {
                    // Let the textfield handle the Enter key to submit
                    return event
                }
                if viewModel.isReorderMode {
                    clipboard.isReordering = false
                    viewModel.isReorderMode = false
                    
                    let freezeLimit = Int(viewModel.reorderFreezeLimit) ?? 0
                    clipboard.applyReorder(target: viewModel.reorderTarget, freezeLimit: freezeLimit)
                    
                    viewModel.reorderTarget = .none
                    viewModel.selectedItemsForDeletion.removeAll()
                    return nil
                }
                
                if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                    let node = displayNodesLocal[viewModel.selectedIndex]
                    if node.isFolder, let folder = node.folder {
                        withAnimation {
                            if viewModel.expandedFolderIds.contains(folder.id) { viewModel.expandedFolderIds.remove(folder.id) }
                            else { viewModel.expandedFolderIds.insert(folder.id) }
                        }
                    } else {
                        let hasCmd = event.modifierFlags.contains(.command)
                        let hasCtrl = event.modifierFlags.contains(.control)
                        let format: PasteFormatType = (hasCmd && hasCtrl) ? .richNoLinks : (hasCmd ? .rich : .plain)
                        pasteItem(viewModel.selectedIndex, format)
                    }
                }
                return nil
            case 124: // Right
                if viewModel.editingFolderId != nil { return event }
                if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                    let node = displayNodesLocal[viewModel.selectedIndex]
                    if node.isFolder, let folder = node.folder {
                        withAnimation { _ = viewModel.expandedFolderIds.insert(folder.id) }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { viewModel.expandedItemIndex = viewModel.selectedIndex }
                    }
                }
                return nil
            case 123: // Left
                if viewModel.editingFolderId != nil { return event }
                if viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                    let node = displayNodesLocal[viewModel.selectedIndex]
                    if event.modifierFlags.contains(.option) {
                        if let parentId = node.parentFolderId ?? node.folder?.id {
                            withAnimation {
                                viewModel.expandedFolderIds.remove(parentId)
                                if let pIdx = displayNodesLocal.firstIndex(where: { $0.folder?.id == parentId }) { viewModel.selectedIndex = pIdx }
                                viewModel.expandedItemIndex = nil
                            }
                        }
                        return nil
                    }
                    if node.isFolder, let folder = node.folder {
                        withAnimation { _ = viewModel.expandedFolderIds.remove(folder.id) }
                    } else if viewModel.expandedItemIndex == viewModel.selectedIndex {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { viewModel.expandedItemIndex = nil }
                    } else if viewModel.activeTab == "Groups", let parentId = node.parentFolderId {
                        if let pIdx = displayNodesLocal.firstIndex(where: { $0.folder?.id == parentId }) {
                            withAnimation { viewModel.selectedIndex = pIdx; viewModel.expandedItemIndex = nil }
                        }
                    }
                }
                return nil
            case 49: // Space
                if (viewModel.isEditMode || viewModel.isReorderMode) && viewModel.selectedIndex >= 0 && viewModel.selectedIndex < displayNodesLocal.count {
                    if let anchor = viewModel.selectionAnchorIndex {
                        let start = min(anchor, viewModel.selectedIndex)
                        let end = max(anchor, viewModel.selectedIndex)
                        
                        var idsToToggle: [UUID] = []
                        for i in start...end {
                            if i < displayNodesLocal.count {
                                if let id = displayNodesLocal[i].item?.id { idsToToggle.append(id) }
                                else if let id = displayNodesLocal[i].folder?.id, id != cloudFolderId, clipboard.selectedDevice == "Local (This Mac)" { idsToToggle.append(id) }
                            }
                        }
                        
                        let allSelected = idsToToggle.allSatisfy { viewModel.selectedItemsForDeletion.contains($0) }
                        withAnimation {
                            for id in idsToToggle {
                                if allSelected {
                                    viewModel.selectedItemsForDeletion.remove(id)
                                } else {
                                    viewModel.selectedItemsForDeletion.insert(id)
                                }
                            }
                            viewModel.selectionAnchorIndex = nil
                        }
                    } else {
                        let node = displayNodesLocal[viewModel.selectedIndex]
                        if let id = node.item?.id ?? (node.folder?.id != cloudFolderId && clipboard.selectedDevice == "Local (This Mac)" ? node.folder?.id : nil) {
                            withAnimation {
                                if viewModel.selectedItemsForDeletion.contains(id) { viewModel.selectedItemsForDeletion.remove(id) }
                                else { viewModel.selectedItemsForDeletion.insert(id) }
                            }
                        }
                    }
                    return nil
                }
                return event

            case 14: // E
                if event.modifierFlags.contains(.command) {
                    withAnimation {
                        viewModel.isEditMode.toggle()
                        if viewModel.isEditMode {
                            if viewModel.isReorderMode {
                                clipboard.history = viewModel.reorderBackupHistory
                                clipboard.folders = viewModel.reorderBackupFolders
                                clipboard.isReordering = false
                                viewModel.isReorderMode = false
                            }
                        } else {
                            viewModel.selectedItemsForDeletion.removeAll()
                        }
                    }
                    return nil
                }
                return event
            case 0: // A
                if (viewModel.isEditMode || viewModel.isReorderMode) && event.modifierFlags.contains(.command) {
                    withAnimation {
                        let ids = Set(displayNodesLocal.compactMap { $0.item?.id ?? (clipboard.selectedDevice == "Local (This Mac)" && $0.folder?.id != cloudFolderId ? $0.folder?.id : nil) })
                        if viewModel.selectedItemsForDeletion.isSuperset(of: ids) { viewModel.selectedItemsForDeletion.subtract(ids) }
                        else { viewModel.selectedItemsForDeletion.formUnion(ids) }
                    }
                    return nil
                }
                return event
            case 53: // Esc
                if viewModel.activeTab == "Trash" {
                    viewModel.activeTab = viewModel.previousTab
                    return nil
                }
                if viewModel.isEditMode {
                    viewModel.isEditMode = false
                    return nil
                }
                if isSearchFocused { _isSearchFocused.wrappedValue = false }
                else if viewModel.isReorderMode {
                    clipboard.history = viewModel.reorderBackupHistory
                    clipboard.folders = viewModel.reorderBackupFolders
                    clipboard.isReordering = false
                    viewModel.isReorderMode = false
                    viewModel.selectedItemsForDeletion.removeAll()
                }
                else if viewModel.isEditMode {
                    viewModel.isEditMode = false
                    viewModel.selectedItemsForDeletion.removeAll()
                }
                else { 
                    if SettingsWindowManager.shared.isSettingsOpen {
                        SettingsWindowManager.shared.closeSettings()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { shortcut.isExpanded = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            previousApp?.activate(options: [])
                        }
                    }
                }
                return nil
            case 48: // Tab
                if event.modifierFlags.contains(.option) {
                    if viewModel.isReorderMode { return nil }
                    let isShift = event.modifierFlags.contains(.shift)
                    let visibleTabs = self.getVisibleTabs()
                    if let currentIndex = visibleTabs.firstIndex(of: viewModel.activeTab) {
                        let nextIndex = isShift 
                            ? (currentIndex - 1 + visibleTabs.count) % visibleTabs.count 
                            : (currentIndex + 1) % visibleTabs.count
                        withAnimation {
                            viewModel.activeTab = visibleTabs[nextIndex]
                            viewModel.selectedIndex = 0
                            viewModel.expandedItemIndex = nil
                        }
                    } else {
                        // We are in a tab not in visibleTabs (like Trash). Jump to first or last tab.
                        withAnimation {
                            viewModel.activeTab = isShift ? (visibleTabs.last ?? "All") : (visibleTabs.first ?? "All")
                            viewModel.selectedIndex = 0
                            viewModel.expandedItemIndex = nil
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
}

struct DeviceSwitcherView: View {
    let devices: [String]
    let onSelect: (String) -> Void
    let onCancel: () -> Void
    
    @State private var selectedIndex: Int = 0
    @State private var localEventMonitor: Any?
    @Environment(\.controlActiveState) private var controlActiveState
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Select Device Source")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.primary.opacity(0.05))
            
            Divider()
            
            VStack(spacing: 4) {
                ForEach(Array(devices.enumerated()), id: \.element) { index, device in
                    HStack {
                        Text(device)
                            .font(.system(size: 13, weight: index == selectedIndex ? .semibold : .regular))
                            .foregroundColor(index == selectedIndex ? .white : .primary)
                        Spacer()
                        if index == selectedIndex {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        index == selectedIndex 
                        ? (controlActiveState == .key ? Color(nsColor: .selectedContentBackgroundColor) : Color(nsColor: .unemphasizedSelectedContentBackgroundColor)) 
                        : Color.clear
                    )
                    .cornerRadius(6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(device)
                    }
                }
            }
            .padding(8)
        }
        .onAppear {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                switch event.keyCode {
                case 125: // Down arrow
                    if selectedIndex < devices.count - 1 {
                        selectedIndex += 1
                    }
                    return nil
                case 126: // Up arrow
                    if selectedIndex > 0 {
                        selectedIndex -= 1
                    }
                    return nil
                case 36: // Enter
                    onSelect(devices[selectedIndex])
                    return nil
                case 53: // Esc
                    onCancel()
                    return nil
                default:
                    return event
                }
            }
        }
        .onDisappear {
            if let monitor = localEventMonitor {
                NSEvent.removeMonitor(monitor)
                localEventMonitor = nil
            }
        }
    }

}
