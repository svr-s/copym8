import SwiftUI

struct ClipboardListView: View {
    @EnvironmentObject var clipboard: ClipboardManager
    var displayNodes: [DisplayNode]
    var isDense: Bool
    @Binding var selectedIndex: Int
    @Binding var selectionAnchorIndex: Int?
    @Binding var expandedItemIndex: Int?
    var activeColorName: String
    var activeColor: Color
    var isEditMode: Bool
    @Binding var selectedItemsForDeletion: Set<UUID>
    @Binding var expandedFolderIds: Set<UUID>
    @Binding var editingFolderId: UUID?
    var activeTab: String
    var pasteItem: (Int, PasteFormatType) -> Void
    
    private func isHighlighted(_ index: Int, id: UUID?) -> Bool {
        if let id = id, selectedItemsForDeletion.contains(id) {
            return true
        }
        if let anchor = selectionAnchorIndex {
            return index >= min(anchor, selectedIndex) && index <= max(anchor, selectedIndex)
        }
        return index == selectedIndex
    }
    
    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                LazyVStack(spacing: isDense ? 2 : 12) {
                    let standardFolders = clipboard.folders.filter { $0.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }
                    ForEach(Array(displayNodes.enumerated()), id: \.element.id) { index, node in
                        if node.isFolder, let folder = node.folder {
                            ClipboardFolderView(
                                folder: folder,
                                shortcutIndex: standardFolders.firstIndex(where: { $0.id == folder.id }),
                                isSelected: isHighlighted(index, id: folder.id),
                                isDense: isDense,
                                activeColor: activeColor,
                                isEditMode: isEditMode,
                                isChecked: selectedItemsForDeletion.contains(folder.id),
                                editingFolderId: $editingFolderId,
                                onTap: {
                                if !isEditMode {
                                        withAnimation {
                                            if expandedFolderIds.contains(folder.id) {
                                                expandedFolderIds.remove(folder.id)
                                            } else {
                                                expandedFolderIds.insert(folder.id)
                                            }
                                            selectedIndex = index
                                        }
                                    } else {
                                        if NSEvent.modifierFlags.contains(.shift), let anchor = selectionAnchorIndex {
                                            let start = min(anchor, index)
                                            let end = max(anchor, index)
                                            for i in start...end {
                                                let n = displayNodes[i]
                                                if let id = n.item?.id { selectedItemsForDeletion.insert(id) }
                                                if let id = n.folder?.id { selectedItemsForDeletion.insert(id) }
                                            }
                                            selectedIndex = index
                                        } else {
                                            if selectedItemsForDeletion.contains(folder.id) { selectedItemsForDeletion.remove(folder.id) }
                                            else { selectedItemsForDeletion.insert(folder.id) }
                                            selectionAnchorIndex = index
                                            selectedIndex = index
                                        }
                                    }
                                },
                                isExpanded: expandedFolderIds.contains(folder.id)
                            )
                            .id(node.id)
                        } else if node.isDivider {
                            Divider()
                                .background(activeColorName == "Black" ? .primary.opacity(0.2) : activeColor.opacity(0.3))
                                .padding(.vertical, 4)
                                .padding(.leading, node.parentFolderId != nil ? 16 + 24 : 16)
                                .padding(.trailing, 16)
                                .id(node.id)
                        } else if let item = node.item {
                            HStack {
                                if node.parentFolderId != nil {
                                    Spacer().frame(width: 24) // Indent items inside folders
                                }
                                ClipboardItemView(
                                    item: item,
                                    shortcutIndex: getRelativeIndex(for: node.id),
                                    isSelected: isHighlighted(index, id: item.id),
                                    isExpanded: index == expandedItemIndex,
                                    isDense: isDense,
                                    activeColor: activeColorName == "Black" ? .primary : activeColor,
                                    isEditMode: isEditMode,
                                    isChecked: selectedItemsForDeletion.contains(item.id),
                                    folderIdentifier: getFolderIdentifier(for: item),
                                    onPaste: {
                                        if isEditMode {
                                            if NSEvent.modifierFlags.contains(.shift), let anchor = selectionAnchorIndex {
                                                let start = min(anchor, index)
                                                let end = max(anchor, index)
                                                for i in start...end {
                                                    let n = displayNodes[i]
                                                    if let id = n.item?.id { selectedItemsForDeletion.insert(id) }
                                                    if let id = n.folder?.id { selectedItemsForDeletion.insert(id) }
                                                }
                                                selectedIndex = index
                                            } else {
                                                if selectedItemsForDeletion.contains(item.id) { selectedItemsForDeletion.remove(item.id) }
                                                else { selectedItemsForDeletion.insert(item.id) }
                                                selectionAnchorIndex = index
                                                selectedIndex = index
                                            }
                                        } else {
                                            let hasCmd = NSEvent.modifierFlags.contains(.command)
                                            let hasOpt = NSEvent.modifierFlags.contains(.option)
                                            let format: PasteFormatType = hasOpt ? .richNoLinks : (hasCmd ? .rich : .plain)
                                            pasteItem(index, format)
                                        }
                                    },
                                    onExpandToggle: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            if expandedItemIndex == index { expandedItemIndex = nil }
                                            else { expandedItemIndex = index }
                                        }
                                    }
                                )
                            }
                            .contextMenu {
                                Button(item.isPinned ? "Unpin" : "Pin") { clipboard.togglePin(for: item.id) }
                                Button("Delete") { clipboard.deleteItems(where: { $0.id == item.id }) }
                            }
                            .id(node.id)
                        }
                    }

                }
                .padding(8)
                .onChange(of: selectedIndex) { _, newIndex in
                    if newIndex >= 0 && newIndex < displayNodes.count {
                        let targetId = displayNodes[newIndex].id
                        proxy.scrollTo(targetId, anchor: nil)
                    }
                }
            }
        }
    }
    
    private func getFolderIdentifier(for item: ClipboardItem) -> String? {
        if activeTab != "Groups", let folderId = item.folderId {
            if let folderIndex = clipboard.folders.firstIndex(where: { $0.id == folderId }) {
                return String(UnicodeScalar(UInt8(65 + folderIndex)))
            }
        }
        return nil
    }
    
    private func getRelativeIndex(for nodeId: String) -> Int? {
        if activeTab == "Groups" {
            var currentFolderId: UUID? = nil
            var count = 0
            for node in displayNodes {
                if node.isFolder {
                    currentFolderId = node.folder?.id
                    count = 0
                } else if node.parentFolderId == currentFolderId {
                    if !node.isDivider {
                        if node.id == nodeId { return count < 10 ? count : nil }
                        count += 1
                    }
                }
            }
        } else {
            var count = 0
            for node in displayNodes {
                if !node.isFolder && !node.isDivider {
                    if node.id == nodeId { return count < 10 ? count : nil }
                    count += 1
                }
            }
        }
        return nil
    }
}
