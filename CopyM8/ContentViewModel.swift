import SwiftUI
import AppKit

/// `ContentViewModel` manages the presentation logic and state for the main `ContentView`.
/// It extracts the visual state (like edit mode, selected items, active tabs, and modals)
/// out of the main view to keep the UI declarative and decoupled from business logic.
@MainActor
class ContentViewModel: ObservableObject {
    
    // MARK: - View State & Modals
    
    /// Tracks if the user is hovering over the pill view to show window controls.
    @Published var isHovering = false
    
    /// Controls the visibility of the "Delete Selected" confirmation modal.
    @Published var showingDeleteSelectedAlert = false
    
    /// Controls the visibility of the "Delete Folder" confirmation modal.
    @Published var showingFolderDeleteAlert = false
    
    /// Controls the visibility of the "Ungroup" confirmation modal.
    @Published var showingUngroupAlert = false
    
    /// Stores the index of the clipboard item currently expanded for detailed viewing.
    @Published var expandedItemIndex: Int? = nil
    
    /// Tracks the ID of the folder currently being renamed.
    @Published var editingFolderId: UUID? = nil
    
    /// Controls the visibility of the group assignment modal.
    @Published var showingGroupAssignment = false
    
    /// Holds the payload for the item currently being assigned to a folder.
    @Published var itemToAssignGroup: GroupAssignmentPayload? = nil
    
    /// Controls the visibility of the local/network device switcher modal.
    @Published var showingDeviceSwitcher = false
    
    /// Stores the previously active tab (e.g., "All", "Groups") for navigation state restoration.
    @Published var previousTab: String = "All"
    
    /// Controls the visibility of the "Empty Trash" confirmation modal.
    @Published var showingEmptyTrashAlert: Bool = false
    
    /// Shows a temporary toast warning when trying to edit a read-only remote clipboard.
    @Published var showingReadOnlyToast: Bool = false
    
    /// Shows a temporary toast indicating a successful import.
    @Published var showingImportSuccessToast: Bool = false
    
    /// Custom message displayed in the import success toast.
    @Published var importSuccessMessage: String = "Import successful"
    
    /// Tracks the user's setting for how many history items to retain.
    @Published var draftHistoryCount: Int = 25
    
    /// The current search query string entered by the user.
    @Published var searchText: String = ""
    
    // MARK: - Editing State
    
    /// Indicates whether the UI is in multi-select "Edit Mode".
    @Published var isEditMode: Bool = false
    
    /// Holds the set of UUIDs for items selected during "Edit Mode" for bulk operations.
    @Published var selectedItemsForDeletion: Set<UUID> = []
    
    // MARK: - Reordering State
    
    /// Indicates whether the user is actively drag-and-drop reordering items.
    @Published var isReorderMode: Bool = false
    
    /// The target state for the current reordering operation.
    @Published var reorderTarget: ReorderTarget? = nil
    
    /// The maximum number of items frozen at the top (unaffected by regular eviction).
    @Published var reorderFreezeLimit: String = "0"
    
    @Published var reorderQueuePlayhead: String = ""
    
    /// A snapshot of the clipboard history before reordering started, allowing cancellation.
    @Published var reorderBackupHistory: [ClipboardItem] = []
    
    /// A snapshot of the clipboard folders before reordering started, allowing cancellation.
    @Published var reorderBackupFolders: [ClipboardFolder] = []
    
    /// A snapshot of the clipboard queue IDs before reordering started, allowing cancellation.
    @Published var reorderBackupQueueIDs: [UUID] = []
    
    // MARK: - Navigation State
    
    /// The currently active tab name (e.g., "All", "Groups", "Trash").
    @Published var activeTab: String = "All"
    
    /// The UUID of the currently selected folder in the sidebar/groups tab.
    @Published var selectedFolderId: UUID? = nil
    
    /// A set of UUIDs for folders that are currently expanded in the sidebar.
    @Published var expandedFolderIds: Set<UUID> = []
    
    /// The array index of the currently focused or highlighted clipboard item (for keyboard navigation).
    @Published var selectedIndex: Int = 0
    
    /// The index where a shift-click selection started (for multi-select).
    @Published var selectionAnchorIndex: Int? = nil
    
    // MARK: - Actions
    
    /// Toggles "Edit Mode" on or off, handling state cleanup.
    /// - Parameter clipboard: The main `ClipboardManager` instance to rollback changes if reordering is canceled.
    func toggleEditMode(clipboard: ClipboardManager) {
        withAnimation {
            isEditMode.toggle()
            if isEditMode {
                if isReorderMode {
                    // Cancel reorder if switching to edit mode
                    clipboard.history = reorderBackupHistory
                    clipboard.folders = reorderBackupFolders
                    clipboard.isReordering = false
                    isReorderMode = false
                }
            } else {
                // Clear selections when exiting edit mode
                selectedItemsForDeletion.removeAll()
            }
        }
    }
}
