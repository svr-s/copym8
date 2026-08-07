import SwiftUI

struct EditModeFooterView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    @Binding var selectedItemsForDeletion: Set<UUID>
    @Binding var isEditMode: Bool
    @Binding var showingDeleteSelectedAlert: Bool
    @Binding var showingFolderDeleteAlert: Bool
    @Binding var showingUngroupAlert: Bool
    var displayNodes: [DisplayNode]
    @Binding var itemToAssignGroup: GroupAssignmentPayload?
    var activeTab: String
    
    var body: some View {
        VStack(spacing: 8) {
            let hasFolderSelected = clipboard.folders.contains(where: { selectedItemsForDeletion.contains($0.id) })
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
            
            VStack(spacing: 8) {
                if clipboard.selectedDevice != "Local (This Mac)" {
                    HStack {
                        GhostHoverButton(
                            icon: "square.and.arrow.down",
                            text: "Import",
                            shortcut: "⌘I",
                            color: .blue,
                            isDisabled: selectedItemsForDeletion.isEmpty
                        ) {
                            let itemsToImport = clipboard.activeHistory.filter { selectedItemsForDeletion.contains($0.id) }
                            if !itemsToImport.isEmpty {
                                clipboard.importItems(itemsToImport)
                            }
                            selectedItemsForDeletion.removeAll()
                            isEditMode = false
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        GhostHoverButton(
                            icon: "folder.fill.badge.plus",
                            text: "Group",
                            shortcut: "⌘G",
                            color: .blue,
                            isDisabled: selectedItemsForDeletion.isEmpty || hasFolderSelected
                        ) {
                            itemToAssignGroup = GroupAssignmentPayload(itemIds: selectedItemsForDeletion) {
                                selectedItemsForDeletion.removeAll()
                                isEditMode = false
                            }
                        }
                        
                        if activeTab == "Pinned" {
                            GhostHoverButton(
                                icon: "pin.slash.fill",
                                text: "Unpin",
                                shortcut: "⌘U",
                                color: .blue,
                                isDisabled: selectedItemsForDeletion.isEmpty || hasFolderSelected
                            ) {
                                for id in selectedItemsForDeletion {
                                    if let idx = clipboard.history.firstIndex(where: { $0.id == id }) {
                                        clipboard.history[idx].isPinned = false
                                    }
                                }
                                selectedItemsForDeletion.removeAll()
                                isEditMode = false
                            }
                        } else {
                            GhostHoverButton(
                                icon: "pin.fill",
                                text: "Pin",
                                shortcut: "⌘P",
                                color: .blue,
                                isDisabled: selectedItemsForDeletion.isEmpty || hasFolderSelected
                            ) {
                                for id in selectedItemsForDeletion {
                                    if let idx = clipboard.history.firstIndex(where: { $0.id == id }) {
                                        clipboard.history[idx].isPinned = true
                                        clipboard.setFolderId(for: [id], folderId: nil)
                                    }
                                }
                                selectedItemsForDeletion.removeAll()
                                isEditMode = false
                            }
                        }
                    }
                    
                    HStack(spacing: 8) {
                        let hasGroupedItem = clipboard.history.contains { item in selectedItemsForDeletion.contains(item.id) && item.folderId != nil }
                        if activeTab == "Groups" && hasGroupedItem {
                            GhostHoverButton(
                                icon: "folder.badge.minus",
                                text: "Ungroup",
                                shortcut: "⌘U",
                                color: .blue,
                                isDisabled: selectedItemsForDeletion.isEmpty || hasFolderSelected
                            ) {
                                showingUngroupAlert = true
                            }
                        }
                        
                        GhostHoverButton(
                            icon: "trash.fill",
                            text: "Delete",
                            shortcut: "⌫",
                            color: .red,
                            isDisabled: selectedItemsForDeletion.isEmpty
                        ) {
                            if !selectedItemsForDeletion.isEmpty {
                                let hasFolder = clipboard.folders.contains(where: { selectedItemsForDeletion.contains($0.id) })
                                if hasFolder {
                                    showingFolderDeleteAlert = true
                                } else {
                                    showingDeleteSelectedAlert = true
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 12).background(Color.primary.opacity(0.05))
    }
}
import SwiftUI

struct GhostHoverButton: View {
    let icon: String
    let text: String
    let shortcut: String
    let color: Color
    let isDisabled: Bool
    var maxWidth: CGFloat? = .infinity
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(shortcut.isEmpty ? text : "\(text) \(shortcut)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(isDisabled ? .primary.opacity(0.4) : (isHovering ? .white : color))
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .frame(maxWidth: maxWidth)
            .background(isDisabled ? Color.primary.opacity(0.1) : (isHovering ? color : color.opacity(0.15)))
            .cornerRadius(6)
            .animation(.easeInOut(duration: 0.1), value: isHovering)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .onHover { hover in
            isHovering = hover && !isDisabled
        }
    }
}
