import SwiftUI
import AppKit

@MainActor
class ContentViewModel: ObservableObject {
    @Published var isHovering = false
    @Published var showingDeleteSelectedAlert = false
    @Published var showingFolderDeleteAlert = false
    @Published var showingUngroupAlert = false
    @Published var expandedItemIndex: Int? = nil
    @Published var editingFolderId: UUID? = nil
    @Published var showingGroupAssignment = false
    @Published var itemToAssignGroup: GroupAssignmentPayload? = nil
    @Published var showingDeviceSwitcher = false
    @Published var previousTab: String = "All"
    @Published var showingEmptyTrashAlert: Bool = false
    @Published var showingReadOnlyToast: Bool = false
    @Published var showingImportSuccessToast: Bool = false
    @Published var importSuccessMessage: String = "Import successful"
    @Published var draftHistoryCount: Int = 25
    @Published var searchText: String = ""
    
    @Published var isEditMode: Bool = false
    @Published var selectedItemsForDeletion: Set<UUID> = []
    
    @Published var isReorderMode: Bool = false
    @Published var reorderTarget: ReorderTarget? = nil
    @Published var reorderFreezeLimit: String = "0"
    @Published var reorderBackupHistory: [ClipboardItem] = []
    @Published var reorderBackupFolders: [ClipboardFolder] = []
    
    @Published var activeTab: String = "All"
    @Published var selectedFolderId: UUID? = nil
    @Published var expandedFolderIds: Set<UUID> = []
    @Published var selectedIndex: Int = 0
    @Published var selectionAnchorIndex: Int? = nil
    
    func toggleEditMode(clipboard: ClipboardManager) {
        withAnimation {
            isEditMode.toggle()
            if isEditMode {
                if isReorderMode {
                    clipboard.history = reorderBackupHistory
                    clipboard.folders = reorderBackupFolders
                    clipboard.isReordering = false
                    isReorderMode = false
                }
            } else {
                selectedItemsForDeletion.removeAll()
            }
        }
    }
}
