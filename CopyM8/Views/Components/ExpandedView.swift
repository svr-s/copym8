import SwiftUI

/// `ExpandedView` is the primary interface presented when CopyM8 is fully opened.
/// It acts as the orchestrator for the `HeaderView`, `SearchBarView`, `TabBarView`, and `ClipboardListView`,
/// passing down all necessary state bindings and environment objects to support browsing, editing, and managing clipboard items.
struct ExpandedView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    @Binding var isHoveringClose: Bool
    @Binding var isEditMode: Bool
    @Binding var selectedItemsForDeletion: Set<UUID>
    @Binding var isDense: Bool
    @Binding var windowWidth: Double
    @Binding var windowHeight: Double
    @Binding var draftHistoryCount: Int
    @Binding var maxHistoryCount: Int
    @Binding var activeTab: String
    @Binding var previousTab: String
    @Binding var showingEmptyTrashAlert: Bool
    
    @Binding var isReorderMode: Bool
    @Binding var reorderTarget: ReorderTarget?
    @Binding var reorderFreezeLimit: String
    @Binding var reorderBackupHistory: [ClipboardItem]
    @Binding var reorderBackupFolders: [ClipboardFolder]
    var isFreezeFieldFocused: FocusState<Bool>.Binding
    
    @Binding var selectedIndex: Int
    @Binding var selectionAnchorIndex: Int?
    var activeColor: Color
    @Binding var searchText: String
    var isSearchFocused: FocusState<Bool>.Binding
    
    var displayNodes: [DisplayNode]
    @Binding var expandedFolderIds: Set<UUID>
    @Binding var expandedItemIndex: Int?
    @Binding var editingFolderId: UUID?
    var activeColorName: String
    @Binding var showingDeleteSelectedAlert: Bool
    @Binding var showingFolderDeleteAlert: Bool
    @Binding var showingUngroupAlert: Bool
    @Binding var itemToAssignGroup: GroupAssignmentPayload?
    
    @Binding var isResizing: Bool
    @Binding var resizeStartMouse: NSPoint?
    @Binding var resizeStartSize: NSSize?
    
    var adjustWindowFrame: () -> Void
    var snapToEdge: () -> Void
    var pasteItem: (Int, PasteFormatType) -> Void
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HeaderView(
                    isHoveringClose: $isHoveringClose,
                    isEditMode: $isEditMode,
                    selectedItemsForDeletion: $selectedItemsForDeletion,
                    isDense: $isDense,
                    windowWidth: $windowWidth,
                    windowHeight: $windowHeight,
                    draftHistoryCount: $draftHistoryCount,
                    maxHistoryCount: $maxHistoryCount,
                    activeTab: $activeTab,
                    previousTab: $previousTab,
                    adjustWindowFrame: adjustWindowFrame
                )
                
                Spacer().frame(height: 4)
                
                SearchBarView(searchText: $searchText, isSearchFocused: isSearchFocused)
                TabBarView(activeTab: $activeTab, selectedIndex: $selectedIndex, activeColor: activeColor)
                
                if displayNodes.isEmpty {
                    EmptyStateView(searchText: searchText, activeTab: activeTab)
                } else {
                    ClipboardListView(
                        displayNodes: displayNodes,
                        isDense: isDense,
                        selectedIndex: $selectedIndex,
                        selectionAnchorIndex: $selectionAnchorIndex,
                        expandedItemIndex: $expandedItemIndex,
                        activeColorName: activeColorName,
                        activeColor: activeColor,
                        isEditMode: isEditMode || isReorderMode,
                        selectedItemsForDeletion: $selectedItemsForDeletion,
                        expandedFolderIds: $expandedFolderIds,
                        editingFolderId: $editingFolderId,
                        activeTab: activeTab,
                        pasteItem: pasteItem
                    )
                }
                
                if activeTab == "Trash" {
                    TrashFooterView(
                        activeTab: $activeTab,
                        showingEmptyTrashAlert: $showingEmptyTrashAlert,
                        showingDeleteSelectedAlert: $showingDeleteSelectedAlert,
                        selectedItemsForDeletion: $selectedItemsForDeletion,
                        displayNodes: displayNodes,
                        isEditMode: $isEditMode,
                        selectedIndex: $selectedIndex
                    )
                } else if isEditMode {
                    EditModeFooterView(
                        selectedItemsForDeletion: $selectedItemsForDeletion,
                        isEditMode: $isEditMode,
                        showingDeleteSelectedAlert: $showingDeleteSelectedAlert,
                        showingFolderDeleteAlert: $showingFolderDeleteAlert,
                        showingUngroupAlert: $showingUngroupAlert,
                        displayNodes: displayNodes,
                        itemToAssignGroup: $itemToAssignGroup,
                        activeTab: activeTab
                    )
                }
                
                if isReorderMode {
                    ReorderFooterView(
                        isReorderMode: $isReorderMode,
                        reorderTarget: $reorderTarget,
                        reorderFreezeLimit: $reorderFreezeLimit,
                        isFreezeFieldFocused: isFreezeFieldFocused,
                        reorderBackupHistory: $reorderBackupHistory,
                        reorderBackupFolders: $reorderBackupFolders,
                        selectedItemsForDeletion: $selectedItemsForDeletion
                    )
                }
            }
        }
        .frame(width: max(340, windowWidth), height: windowHeight) // Let adjustWindowFrame handle actual screen clamping
        .background(VisualEffectView(material: .windowBackground, blendingMode: .behindWindow))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.2), lineWidth: 1))
        .overlay(
            ResizeEdgesView(
                windowWidth: $windowWidth,
                windowHeight: $windowHeight,
                isResizing: $isResizing,
                resizeStartMouse: $resizeStartMouse,
                resizeStartSize: $resizeStartSize,
                adjustWindowFrame: adjustWindowFrame
            )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

struct TrashFooterView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    @Binding var activeTab: String
    @Binding var showingEmptyTrashAlert: Bool
    @Binding var showingDeleteSelectedAlert: Bool
    @Binding var selectedItemsForDeletion: Set<UUID>
    var displayNodes: [DisplayNode]
    @Binding var isEditMode: Bool
    @Binding var selectedIndex: Int

    private var hasSelection: Bool {
        if isEditMode {
            return !selectedItemsForDeletion.isEmpty
        } else {
            return selectedIndex >= 0 && selectedIndex < displayNodes.count
        }
    }

    private func getSelectedIds() -> [UUID] {
        if isEditMode {
            return Array(selectedItemsForDeletion)
        } else {
            if selectedIndex >= 0 && selectedIndex < displayNodes.count {
                let node = displayNodes[selectedIndex]
                if let id = node.item?.id ?? node.folder?.id {
                    return [id]
                }
            }
            return []
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            if isEditMode {
                HStack {
                    Button(action: {
                        let allIds = Set(displayNodes.compactMap { $0.item?.id ?? $0.folder?.id })
                        if selectedItemsForDeletion.count == allIds.count { selectedItemsForDeletion.removeAll() }
                        else { selectedItemsForDeletion = allIds }
                    }) {
                        let allIdsCount = Set(displayNodes.compactMap { $0.item?.id ?? $0.folder?.id }).count
                        Text(selectedItemsForDeletion.count == allIdsCount && allIdsCount > 0 ? "Deselect All" : "Select All")
                            .font(.system(size: 11)).foregroundColor(.primary.opacity(0.6))
                    }.buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Text("\(selectedItemsForDeletion.count) Items Selected")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
            }
            
            HStack(spacing: 8) {
                Button(action: {
                    if isEditMode {
                        if !selectedItemsForDeletion.isEmpty {
                            clipboard.restoreItems(ids: Array(selectedItemsForDeletion))
                            selectedItemsForDeletion.removeAll()
                            isEditMode = false
                        }
                    } else {
                        let ids = getSelectedIds()
                        if !ids.isEmpty {
                            clipboard.restoreItems(ids: ids)
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Restore")
                    }
                    .font(.system(size: 11, weight: .bold)).foregroundColor(hasSelection ? .primary : .primary.opacity(0.4))
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.primary.opacity(0.1)).cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!hasSelection)
                
                Button(action: {
                    if isEditMode {
                        if !selectedItemsForDeletion.isEmpty {
                            showingDeleteSelectedAlert = true
                        }
                    } else {
                        let ids = getSelectedIds()
                        if !ids.isEmpty {
                            selectedItemsForDeletion = Set(ids)
                            showingDeleteSelectedAlert = true
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                        Text("Delete")
                    }
                    .font(.system(size: 11, weight: .bold)).foregroundColor(hasSelection ? .primary : .primary.opacity(0.4))
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.primary.opacity(0.1)).cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!hasSelection)
                
                Button(action: {
                    showingEmptyTrashAlert = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                        Text("Empty Trash")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.05))
    }
}
