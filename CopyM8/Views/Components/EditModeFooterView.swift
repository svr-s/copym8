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
                HStack(spacing: 8) {
                    Button(action: {
                        itemToAssignGroup = GroupAssignmentPayload(itemIds: selectedItemsForDeletion) {
                            selectedItemsForDeletion.removeAll()
                            isEditMode = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill.badge.plus")
                            Text("Group")
                        }
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.primary)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(Color.primary.opacity(0.1)).cornerRadius(6)
                    }.buttonStyle(PlainButtonStyle())
                    .disabled(selectedItemsForDeletion.isEmpty || hasFolderSelected)
                    
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
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(Color.primary.opacity(0.1)).cornerRadius(6)
                        }.buttonStyle(PlainButtonStyle())
                        .disabled(selectedItemsForDeletion.isEmpty || hasFolderSelected)
                    } else {
                        Button(action: {
                            for id in selectedItemsForDeletion {
                                if let idx = clipboard.history.firstIndex(where: { $0.id == id }) {
                                    clipboard.history[idx].isPinned = true
                                    clipboard.setFolderId(for: [id], folderId: nil)
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
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(Color.primary.opacity(0.1)).cornerRadius(6)
                        }.buttonStyle(PlainButtonStyle())
                        .disabled(selectedItemsForDeletion.isEmpty || hasFolderSelected)
                    }
                }
                
                HStack(spacing: 8) {
                    let hasGroupedItem = clipboard.history.contains { item in selectedItemsForDeletion.contains(item.id) && item.folderId != nil }
                    if activeTab == "Groups" && hasGroupedItem {
                        Button(action: {
                            showingUngroupAlert = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.badge.minus")
                                Text("Ungroup")
                            }
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.primary)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(Color.primary.opacity(0.1)).cornerRadius(6)
                        }.buttonStyle(PlainButtonStyle())
                        .disabled(selectedItemsForDeletion.isEmpty || hasFolderSelected)
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
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(selectedItemsForDeletion.isEmpty ? Color.primary.opacity(0.1) : Color.red.opacity(0.8))
                        .cornerRadius(6)
                    }.buttonStyle(PlainButtonStyle())
                    .disabled(selectedItemsForDeletion.isEmpty)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 12).background(Color.primary.opacity(0.05))
    }
}
