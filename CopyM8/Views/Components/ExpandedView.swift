import SwiftUI

struct ExpandedView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    @Binding var isHoveringClose: Bool
    @Binding var isEditMode: Bool
    @Binding var selectedItemsForDeletion: Set<UUID>
    @Binding var isDense: Bool
    @Binding var windowWidth: Double
    @Binding var windowHeight: Double
    @Binding var showingSettings: Bool
    @Binding var draftHistoryCount: Int
    @Binding var maxHistoryCount: Int
    @Binding var activeTab: String
    
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
    var pasteItem: (Int, Bool) -> Void
    
    var body: some View {
        ZStack {
            NativeDragView(onDragEnded: { snapToEdge() }, onTap: {})
            
            VStack(spacing: 0) {
                HeaderView(
                    isHoveringClose: $isHoveringClose,
                    isEditMode: $isEditMode,
                    selectedItemsForDeletion: $selectedItemsForDeletion,
                    isDense: $isDense,
                    windowWidth: $windowWidth,
                    windowHeight: $windowHeight,
                    showingSettings: $showingSettings,
                    draftHistoryCount: $draftHistoryCount,
                    maxHistoryCount: $maxHistoryCount,
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
                        activeTab: activeTab,
                        pasteItem: pasteItem
                    )
                }
                
                if isEditMode {
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
