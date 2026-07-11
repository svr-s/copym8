import SwiftUI

struct EditModeFooterView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    @Binding var selectedItemsForDeletion: Set<UUID>
    @Binding var isEditMode: Bool
    @Binding var showingDeleteSelectedAlert: Bool
    @Binding var showingFolderDeleteAlert: Bool
    var displayNodes: [DisplayNode]
    @Binding var itemToAssignGroup: GroupAssignmentPayload?
    var activeTab: String
    
    var body: some View {
        VStack(spacing: 8) {
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
            
            HStack(spacing: 8) {
                Spacer()
                
                Button(action: {
                    itemToAssignGroup = GroupAssignmentPayload(itemIds: selectedItemsForDeletion)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill.badge.plus")
                        Text("Group")
                    }
                    .font(.system(size: 11, weight: .bold)).foregroundColor(.primary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.primary.opacity(0.1)).cornerRadius(6)
                }.buttonStyle(PlainButtonStyle())
                .disabled(selectedItemsForDeletion.isEmpty)
                
                if activeTab == "Pinned" {
                    Button(action: {
                        for id in selectedItemsForDeletion {
                            if let idx = clipboard.history.firstIndex(where: { $0.id == id }) {
                                clipboard.history[idx].isPinned = false
                            }
                        }
                        selectedItemsForDeletion.removeAll()
                        isEditMode = false
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pin.slash.fill")
                            Text("Unpin")
                        }
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.primary)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.primary.opacity(0.1)).cornerRadius(6)
                    }.buttonStyle(PlainButtonStyle())
                    .disabled(selectedItemsForDeletion.isEmpty)
                } else {
                    Button(action: {
                        for id in selectedItemsForDeletion {
                            if let idx = clipboard.history.firstIndex(where: { $0.id == id }) {
                                clipboard.history[idx].isPinned = true
                                clipboard.history[idx].folderId = nil
                            }
                        }
                        selectedItemsForDeletion.removeAll()
                        isEditMode = false
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pin.fill")
                            Text("Pin")
                        }
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.primary)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.primary.opacity(0.1)).cornerRadius(6)
                    }.buttonStyle(PlainButtonStyle())
                    .disabled(selectedItemsForDeletion.isEmpty)
                }
                
                let hasGroupedItem = clipboard.history.contains { item in selectedItemsForDeletion.contains(item.id) && item.folderId != nil }
                if activeTab == "Groups" && hasGroupedItem {
                    Button(action: {
                        for i in 0..<clipboard.history.count {
                            if selectedItemsForDeletion.contains(clipboard.history[i].id) {
                                clipboard.history[i].folderId = nil
                            }
                        }
                        selectedItemsForDeletion.removeAll()
                        isEditMode = false
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.minus")
                            Text("Ungroup")
                        }
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.primary)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.primary.opacity(0.1)).cornerRadius(6)
                    }.buttonStyle(PlainButtonStyle())
                    .disabled(selectedItemsForDeletion.isEmpty)
                }
                
                Button(action: {
                    if !selectedItemsForDeletion.isEmpty {
                        let hasFolder = clipboard.folders.contains(where: { selectedItemsForDeletion.contains($0.id) })
                        if hasFolder {
                            showingFolderDeleteAlert = true
                        } else {
                            showingDeleteSelectedAlert = true
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                        Text("Delete")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(selectedItemsForDeletion.isEmpty ? .primary.opacity(0.4) : .white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(selectedItemsForDeletion.isEmpty ? Color.primary.opacity(0.1) : Color.red.opacity(0.8))
                    .cornerRadius(6)
                }.buttonStyle(PlainButtonStyle())
                .disabled(selectedItemsForDeletion.isEmpty)
            }
            .alert("Delete selected items?", isPresented: $showingDeleteSelectedAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) { deleteSelectedItems() }
            } message: {
                Text("Are you sure you want to delete \(selectedItemsForDeletion.count) items? This action cannot be undone.")
            }
            .alert("Delete selected folders?", isPresented: $showingFolderDeleteAlert) {
                Button("Keep Items", role: .none) { deleteFolders(keepItems: true) }
                Button("Delete All", role: .destructive) { deleteFolders(keepItems: false) }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Do you want to keep the items inside the folders (move to Pinned) or delete them permanently?")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 12).background(Color.primary.opacity(0.05))
    }
    
    private func deleteSelectedItems() {
        clipboard.history.removeAll { selectedItemsForDeletion.contains($0.id) }
        selectedItemsForDeletion.removeAll()
        isEditMode = false
    }
    
    private func deleteFolders(keepItems: Bool) {
        let folderIds = selectedItemsForDeletion.filter { id in clipboard.folders.contains(where: { $0.id == id }) }
        
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
        
        // Also delete any regular items that were selected
        let itemIds = selectedItemsForDeletion.subtracting(folderIds)
        if !itemIds.isEmpty {
            clipboard.history.removeAll { itemIds.contains($0.id) }
        }
        
        selectedItemsForDeletion.removeAll()
        isEditMode = false
    }
}
